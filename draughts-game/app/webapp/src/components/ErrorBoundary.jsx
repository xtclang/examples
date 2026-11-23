import { Component } from 'react';

/**
 * Catches a rendering error anywhere below it, so a bug in one screen shows a message and a way
 * back instead of unmounting the whole page and leaving it blank.
 *
 * `resetKey` changes when the person moves to another page, which clears the error.
 */
export default class ErrorBoundary extends Component {
  state = { error: null };

  static getDerivedStateFromError(error) {
    return { error };
  }

  componentDidUpdate(previous) {
    if (this.state.error && previous.resetKey !== this.props.resetKey) this.setState({ error: null });
  }

  componentDidCatch(error, info) {
    console.error('The page hit an error:', error, info?.componentStack);
  }

  render() {
    if (!this.state.error) return this.props.children;
    return (
      <div className="lobby">
        <div className="lobby-card" role="alert">
          <h2>Something went wrong</h2>
          <p className="lobby-lead">
            The page hit an unexpected error. Your game is safe on the server — reload to carry on.
          </p>
          <div className="room-actions">
            <button className="btn btn-solid" onClick={() => window.location.reload()}>
              Reload
            </button>
            <button className="btn" onClick={() => this.setState({ error: null })}>
              Try again
            </button>
          </div>
        </div>
      </div>
    );
  }
}
