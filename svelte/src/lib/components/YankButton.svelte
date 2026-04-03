<script lang="ts">
  import type { components } from '@crates-io/api-client';
  import type { HTMLButtonAttributes } from 'svelte/elements';

  import { createClient } from '@crates-io/api-client';

  type Version = components['schemas']['Version'];

  interface Props extends HTMLButtonAttributes {
    crateName: string;
    version: Version;
    onChanged?: () => void | Promise<void>;
  }

  let { crateName, version = $bindable(), onChanged, ...others }: Props = $props();

  let client = createClient({ fetch });
  let isLoading = $state(false);

  async function toggle() {
    isLoading = true;
    try {
      let params = { path: { name: crateName, version: version.num } };

      if (version.yanked) {
        let { response } = await client.PUT('/api/v1/crates/{name}/{version}/unyank', { params });
        if (!response.ok) return;
        version.yanked = false;
      } else {
        let { response } = await client.DELETE('/api/v1/crates/{name}/{version}/yank', { params });
        if (!response.ok) return;
        version.yanked = true;
      }

      await onChanged?.();
    } finally {
      isLoading = false;
    }
  }
</script>

{#if version.yanked}
  <button type="button" {...others} data-test-version-unyank-button={version.num} disabled={isLoading} onclick={toggle}>
    {#if isLoading}
      Unyanking...
    {:else}
      Unyank
    {/if}
  </button>
{:else}
  <button type="button" {...others} data-test-version-yank-button={version.num} disabled={isLoading} onclick={toggle}>
    {#if isLoading}
      Yanking...
    {:else}
      Yank
    {/if}
  </button>
{/if}
