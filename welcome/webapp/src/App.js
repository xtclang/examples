import React, {Component} from 'react'


class App extends Component {

    constructor() {
      super();
      this.state = {seconds: 0, count: 0};
      this.handleClick = this.handleClick.bind(this);
      }

    tick() {
      this.setState(state => ({seconds: state.seconds + 1}));
    }

    handleClick() {
      this.setState(state => ({seconds: 0}));
      }

    componentDidMount() {
      this.interval = setInterval(() => this.tick(), 1000);
      fetch('/welcome')
        .then(response => response.text())
        .then(data => this.setState(state => ({count: data})));
    }

    componentWillUnmount() {
      clearInterval(this.interval);
    }

    render() {
      return (
        <div>
          Welcome! You are visitor #{this.state.count}
          <p/>
          <button onClick={this.handleClick}>Reset timer</button>
          <p/>
          Timer:{this.state.seconds}
        </div>
        );
      }
  }

export default App