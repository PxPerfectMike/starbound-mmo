<script lang="ts">
  import { onMount, onDestroy } from 'svelte'
  import { createMarketConnection } from '$lib/partykit/client'
  import { CURRENCY_SYMBOL } from '@starbound-mmo/shared'

  const market = createMarketConnection()
  const { listings, connected, error } = market

  let searchQuery = $state('')
  let sortBy = $state<'newest' | 'price_low' | 'price_high'>('newest')

  const filteredListings = $derived(() => {
    let result = [...$listings]

    if (searchQuery) {
      const query = searchQuery.toLowerCase()
      result = result.filter((l) => l.itemName.toLowerCase().includes(query))
    }

    switch (sortBy) {
      case 'price_low':
        result.sort((a, b) => a.pricePerUnit - b.pricePerUnit)
        break
      case 'price_high':
        result.sort((a, b) => b.pricePerUnit - a.pricePerUnit)
        break
      case 'newest':
      default:
        result.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime())
    }

    return result
  })

  onMount(() => {
    market.connect()
  })

  onDestroy(() => {
    market.disconnect()
  })

  function formatTimeAgo(date: Date | string) {
    const now = new Date()
    const then = new Date(date)
    const seconds = Math.floor((now.getTime() - then.getTime()) / 1000)

    if (seconds < 60) return 'just now'
    if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`
    if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`
    return `${Math.floor(seconds / 86400)}d ago`
  }
</script>

<svelte:head>
  <title>Market - Starbound MMO</title>
</svelte:head>

<div class="container">
  <header class="page-header">
    <h1>Global Market</h1>
    <div class="connection-status">
      {#if $connected}
        <span class="badge badge-success">Connected</span>
      {:else}
        <span class="badge badge-error">Disconnected</span>
      {/if}
    </div>
  </header>

  {#if $error}
    <div class="alert alert-error">{$error}</div>
  {/if}

  <div class="controls">
    <input
      type="text"
      class="input search-input"
      placeholder="Search items..."
      bind:value={searchQuery}
    />

    <select class="input sort-select" bind:value={sortBy}>
      <option value="newest">Newest First</option>
      <option value="price_low">Price: Low to High</option>
      <option value="price_high">Price: High to Low</option>
    </select>

    <button class="btn btn-secondary" onclick={() => market.refresh()}>
      Refresh
    </button>
  </div>

  <div class="listings-grid">
    {#each filteredListings() as listing (listing.id)}
      <div class="card listing-card">
        <div class="listing-header">
          <h3 class="item-name">{listing.itemName}</h3>
          <span class="item-count">x{listing.itemCount}</span>
        </div>

        <div class="listing-price">
          <span class="price-per-unit">
            <span class="credits">{listing.pricePerUnit} {CURRENCY_SYMBOL}</span>
            <span class="per-unit">/ each</span>
          </span>
          <span class="price-total">
            Total: <span class="credits">{listing.totalPrice} {CURRENCY_SYMBOL}</span>
          </span>
        </div>

        <div class="listing-meta">
          <span class="seller">Seller: {listing.seller.displayName}</span>
          <span class="time">{formatTimeAgo(listing.createdAt)}</span>
        </div>

        <div class="listing-actions">
          <button class="btn btn-primary btn-small">Buy Now</button>
        </div>
      </div>
    {:else}
      <div class="empty-state">
        {#if $connected}
          <p>No listings found. The market is empty or no items match your search.</p>
        {:else}
          <p>Connecting to market...</p>
        {/if}
      </div>
    {/each}
  </div>
</div>

<style>
  .page-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 2rem;
  }

  .page-header h1 {
    font-size: 2rem;
  }

  .controls {
    display: flex;
    gap: 1rem;
    margin-bottom: 1.5rem;
    flex-wrap: wrap;
  }

  .search-input {
    flex: 1;
    min-width: 200px;
  }

  .sort-select {
    width: auto;
    min-width: 150px;
  }

  .listings-grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
    gap: 1rem;
  }

  .listing-card {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
  }

  .listing-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .item-name {
    font-size: 1.125rem;
    font-weight: 600;
  }

  .item-count {
    color: var(--color-text-muted);
    font-size: 0.875rem;
  }

  .listing-price {
    display: flex;
    flex-direction: column;
    gap: 0.25rem;
  }

  .price-per-unit {
    font-size: 1.25rem;
  }

  .per-unit {
    color: var(--color-text-muted);
    font-size: 0.875rem;
  }

  .price-total {
    color: var(--color-text-muted);
    font-size: 0.875rem;
  }

  .listing-meta {
    display: flex;
    justify-content: space-between;
    color: var(--color-text-muted);
    font-size: 0.75rem;
  }

  .listing-actions {
    margin-top: auto;
    padding-top: 0.5rem;
  }

  .btn-small {
    padding: 0.5rem 1rem;
    font-size: 0.8125rem;
    width: 100%;
  }

  .empty-state {
    grid-column: 1 / -1;
    text-align: center;
    padding: 3rem;
    color: var(--color-text-muted);
  }

  .alert {
    padding: 1rem;
    border-radius: 6px;
    margin-bottom: 1rem;
  }

  .alert-error {
    background: rgba(239, 68, 68, 0.15);
    border: 1px solid var(--color-error);
    color: var(--color-error);
  }
</style>
