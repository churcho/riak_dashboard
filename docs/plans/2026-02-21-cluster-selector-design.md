# Cluster Selector Design

## Problem

The sidebar has separate "Cluster" and "Nodes" nav links that both route to the same `ClusterLive` view showing identical content. The app connects to a single Riak cluster with no way to switch.

## Solution

Replace the "Cluster" nav link with a dropdown selector at the top of the sidebar (below the logo, above the MONITORING section). The selector shows the current cluster name and lets users switch to remote datacenters discovered via the WebSocket `riak_cluster` event.

## Data Source

The `remote_dcs` array from the existing WebSocket stream. Each entry contains:
- `name` — display name for the DC
- `admin_url` — the base URL to connect to

The currently connected cluster is always shown as the default/active option.

## UI

- Styled button at the top of the sidebar: Riak icon + "Cluster" label + current cluster name + chevron-down
- Click opens a dropdown listing the current cluster (marked active) and all remote DCs
- Selecting a different cluster triggers a WebSocket reconnection

## Switch Behavior

1. User selects a remote DC from the dropdown
2. LiveView sends `select_cluster` event with the new `admin_url`
3. LiveView updates `ws_url` assign and pushes it to the JS hook
4. JS hook disconnects current WebSocket, connects to the new URL
5. Loading state shows while reconnecting
6. Existing event handlers reload all cluster data

## Files Changed

- `shell.ex` — Remove "Cluster" from nav items, add cluster selector component above nav
- `cluster_live.ex` — Track selected/available clusters, handle `select_cluster` event
- `riak_events.js` — Support dynamic URL changes (disconnect + reconnect)
- `router.ex` — Clean up route duplication
