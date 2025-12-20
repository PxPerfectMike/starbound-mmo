<script lang="ts">
  // Home page - overview dashboard
</script>

<svelte:head>
  <title>Starbound MMO - Home</title>
</svelte:head>

<div class="container">
  <section class="hero">
    <h1>Welcome to Starbound MMO</h1>
    <p>A persistent multiplayer universe with player-driven economy, factions, and shared exploration.</p>
  </section>

  <div class="features">
    <div class="card feature">
      <h3>Global Market</h3>
      <p>Trade items with players across the universe. Buy low, sell high, and build your fortune.</p>
      <a href="/market" class="btn btn-primary">Browse Market</a>
    </div>

    <div class="card feature">
      <h3>Factions</h3>
      <p>Join or create a faction. Build together, share resources, and claim territory.</p>
      <a href="/factions" class="btn btn-primary">View Factions</a>
    </div>

    <div class="card feature">
      <h3>Wild Zones</h3>
      <p>Explore shared planets where you might encounter other players. Adventure awaits!</p>
      <a href="/zones" class="btn btn-primary">Explore Zones</a>
    </div>
  </div>

  <section class="stats">
    <div class="card">
      <h3>Server Status</h3>
      <div class="stat-grid">
        <div class="stat">
          <span class="stat-value">--</span>
          <span class="stat-label">Players Online</span>
        </div>
        <div class="stat">
          <span class="stat-value">--</span>
          <span class="stat-label">Active Listings</span>
        </div>
        <div class="stat">
          <span class="stat-value">--</span>
          <span class="stat-label">Factions</span>
        </div>
      </div>
    </div>
  </section>
</div>

<style>
  .hero {
    text-align: center;
    padding: 3rem 0;
  }

  .hero h1 {
    font-size: 2.5rem;
    margin-bottom: 1rem;
  }

  .hero p {
    color: var(--color-text-muted);
    font-size: 1.125rem;
    max-width: 600px;
    margin: 0 auto;
  }

  .features {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
    gap: 1.5rem;
    margin: 2rem 0;
  }

  .feature {
    display: flex;
    flex-direction: column;
    gap: 1rem;
  }

  .feature h3 {
    font-size: 1.25rem;
  }

  .feature p {
    color: var(--color-text-muted);
    flex: 1;
  }

  .stats {
    margin-top: 2rem;
  }

  .stat-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 2rem;
    margin-top: 1rem;
  }

  .stat {
    text-align: center;
  }

  .stat-value {
    display: block;
    font-size: 2rem;
    font-weight: 700;
    color: var(--color-primary);
  }

  .stat-label {
    color: var(--color-text-muted);
    font-size: 0.875rem;
  }
</style>
