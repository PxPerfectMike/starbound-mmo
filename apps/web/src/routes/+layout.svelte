<script lang="ts">
  import '../app.css'

  let { children } = $props()
</script>

<div class="app">
  <header>
    <nav class="container">
      <a href="/" class="logo">Starbound MMO</a>
      <div class="nav-links">
        <a href="/market">Market</a>
        <a href="/factions">Factions</a>
        <a href="/players">Players</a>
      </div>
    </nav>
  </header>

  <main>
    {@render children()}
  </main>

  <footer>
    <div class="container">
      <p>Starbound MMO - A community multiplayer experience</p>
    </div>
  </footer>
</div>

<style>
  .app {
    display: flex;
    flex-direction: column;
    min-height: 100vh;
  }

  header {
    background: var(--color-surface);
    border-bottom: 1px solid var(--color-border);
    padding: 1rem 0;
  }

  nav {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .logo {
    font-weight: 700;
    font-size: 1.25rem;
    color: var(--color-text);
  }

  .nav-links {
    display: flex;
    gap: 2rem;
  }

  .nav-links a {
    color: var(--color-text-muted);
    transition: color 0.15s ease;
  }

  .nav-links a:hover {
    color: var(--color-text);
    text-decoration: none;
  }

  main {
    flex: 1;
    padding: 2rem 0;
  }

  footer {
    background: var(--color-surface);
    border-top: 1px solid var(--color-border);
    padding: 1.5rem 0;
    text-align: center;
    color: var(--color-text-muted);
    font-size: 0.875rem;
  }
</style>
