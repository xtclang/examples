import React, {Component} from 'react'


class App extends Component {

    constructor() {
      super();
      this.state = {seconds: 0, name: "", count: 0};
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

      fetch('/welcome/org')
        .then(response => response.json())
        .then(name => this.setState(state => ({name: name})));

      fetch('/welcome/count')
        .then(response => response.json())
        .then(data =>
            {
            var count = data == 1 ? 'first'  :
                        data == 2 ? 'second' :
                        data == 3 ? 'third'  :
                                  '' + data + '-th';
            this.setState(state => ({count: count}));
            });
    }

    componentWillUnmount() {
      clearInterval(this.interval);
    }

    render() {
      return (
        <div>
          Welcome to {this.state.name}! This is your {this.state.count} visit to our site!
          <p/>
          <button onClick={this.handleClick}>Reset timer</button>
          <p/>
          Timer:{this.state.seconds}
        </div>
        );
    }
}

export default App