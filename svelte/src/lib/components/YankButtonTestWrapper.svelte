<script lang="ts">
  import type { components } from '@crates-io/api-client';

  import YankButton from './YankButton.svelte';

  type Version = components['schemas']['Version'];

  interface Props {
    crateName: string;
    version: Version;
    onChanged?: () => void | Promise<void>;
    class?: string;
  }

  let { version: initialVersion, ...others }: Props = $props();

  // YankButton mutates `version.yanked` after a successful API call.
  // In the real app, version objects are deeply reactive because they
  // come from SvelteKit's `$state`-wrapped page data. Plain objects
  // passed from tests are not reactive, so mutations don't trigger
  // re-renders. Wrapping the version in `$state` here replicates the
  // real-app reactivity so the component behaves identically in tests.
  // svelte-ignore state_referenced_locally
  let version: Version = $state(initialVersion);
</script>

<YankButton bind:version {...others} />
