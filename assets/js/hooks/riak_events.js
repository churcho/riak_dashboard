// assets/js/hooks/riak_events.js
const RiakEvents = {
  mounted() {
    const url = this.el.dataset.wsUrl;
    const topics = JSON.parse(this.el.dataset.topics || '["cluster"]');
    this.reconnectAttempts = 0;

    if (url) {
      this.connect(url, topics);
    } else {
      // No WebSocket URL configured
      this.pushEvent("ws_not_configured", {});
    }
  },

  connect(url, topics) {
    this.ws = new WebSocket(url);

    this.ws.onopen = () => {
      this.reconnectAttempts = 0;
      this.ws.send(JSON.stringify({action: "subscribe", topics: topics}));
      this.pushEvent("ws_connected", {});
    };

    this.ws.onmessage = (evt) => {
      const msg = JSON.parse(evt.data);
      if (msg.type === "event" || msg.type === "snapshot") {
        this.pushEvent("riak_" + msg.topic, msg.data);
      } else if (msg.type === "backpressure") {
        this.pushEvent("ws_backpressure", msg);
      } else if (msg.type === "error") {
        this.pushEvent("ws_error", msg);
      }
    };

    this.ws.onclose = () => {
      this.pushEvent("ws_disconnected", {});
      const delay = Math.min(1000 * Math.pow(2, this.reconnectAttempts), 30000);
      this.reconnectAttempts++;
      this._reconnectTimer = setTimeout(() => this.connect(url, topics), delay);
    };

    this.ws.onerror = () => this.ws.close();
  },

  destroyed() {
    if (this._reconnectTimer) clearTimeout(this._reconnectTimer);
    if (this.ws) this.ws.close();
  }
};

export default RiakEvents;
