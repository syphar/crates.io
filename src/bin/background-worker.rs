//! Runs enqueued background jobs
//!
//! This binary will loop until interrupted. It will run all jobs in the
//! background queue, sleeping for 1 second whenever the queue is empty. If we
//! are unable to spawn workers to run jobs (either because we couldn't connect
//! to the DB, an error occurred while loading, or we just never heard back from
//! the worker thread), we will rebuild the runner and try again up to 5 times.
//! After the 5th occurrence, we will panic.
//!
//! Usage:
//!      cargo run --bin background-worker

#[macro_use]
extern crate tracing;

use anyhow::Context;
use crates_io::app::create_database_pool;
use crates_io::cloudfront::CloudFront;
use crates_io::fastly::Fastly;
use crates_io::ssh;
use crates_io::storage::Storage;
use crates_io::worker::{Environment, RunnerExt};
use crates_io::{Emails, config};
use crates_io_docs_rs::RealDocsRsClient;
use crates_io_env_vars::var;
use crates_io_index::RepositoryConfig;
use crates_io_og_image::OgImageGenerator;
use crates_io_team_repo::TeamRepoImpl;
use crates_io_worker::Runner;
use object_store::prefix::PrefixStore;
use reqwest::Client;
use std::sync::Arc;
use std::thread::sleep;
use std::time::Duration;

fn main() -> anyhow::Result<()> {
    let _sentry = crates_io::sentry::init();

    // Initialize logging
    crates_io::util::tracing::init();

    let _span = info_span!("swirl.run");

    info!("Booting runner");

    let mut config = config::Server::from_environment()?;

    // Override the pool size to 10 for the background worker
    config.db.primary.pool_size = 10;

    // We run some long-running queries in the background worker, so we need to
    // increase the statement timeout a bit…
    config.db.primary.statement_timeout = Duration::from_secs(4 * 60 * 60);

    let runtime = tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .context("Failed to initialize tokio runtime")?;

    if config.db.are_all_read_only() {
        loop {
            warn!(
                "Cannot run background jobs with a read-only pool. Please scale background_worker \
                to 0 processes until the leader database is available."
            );
            sleep(Duration::from_secs(60));
        }
    }

    if var("HEROKU")?.is_some() {
        ssh::write_known_hosts_file()?;
    }

    let repository_config = RepositoryConfig::from_environment()?;

    let cloudfront = CloudFront::from_environment();
    let storage = Arc::new(Storage::from_config(&config.storage));

    let downloads_archive_store = PrefixStore::new(storage.as_inner(), "archive/version-downloads");
    let downloads_archive_store = Box::new(downloads_archive_store);

    let client = Client::builder()
        .timeout(Duration::from_secs(45))
        .build()
        .expect("Couldn't build client");

    let emails = Emails::from_environment(&config);
    let fastly = Fastly::from_environment(client.clone());
    let team_repo = TeamRepoImpl::default();

    let docs_rs = RealDocsRsClient::from_environment().map(|cl| Box::new(cl) as _);

    let deadpool = create_database_pool(&config.db.primary);

    let environment = Environment::builder()
        .config(Arc::new(config))
        .repository_config(repository_config)
        .maybe_cloudfront(cloudfront)
        .maybe_fastly(fastly)
        .storage(storage)
        .downloads_archive_store(downloads_archive_store)
        .deadpool(deadpool.clone())
        .emails(emails)
        .maybe_docs_rs(docs_rs)
        .team_repo(Box::new(team_repo))
        .og_image_generator(OgImageGenerator::from_environment()?)
        .build();

    let environment = Arc::new(environment);

    std::thread::spawn({
        let environment = environment.clone();
        move || {
            if let Err(err) = environment.lock_index() {
                warn!(%err, "Failed to clone index");
            };
        }
    });

    let runner = Runner::new(deadpool, environment.clone())
        .configure_default_queue(|queue| queue.num_workers(5))
        .configure_queue("downloads", |queue| queue.num_workers(1))
        .configure_queue("repository", |queue| queue.num_workers(1))
        .register_crates_io_job_types();

    runtime.block_on(async {
        let handle = runner.start();

        info!("Runner booted, running jobs");
        handle.wait_for_shutdown().await
    });

    Ok(())
}
