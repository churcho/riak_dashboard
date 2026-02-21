// assets/js/hooks/riak_events.js
const RiakEvents = {
  mounted() {
    this.currentUrl = this.el.dataset.wsUrl;
    const topics = JSON.parse(this.el.dataset.topics || '["cluster"]');
    this.topics = topics;
    this.reconnectAttempts = 0;

    if (this.currentUrl) {
      this.connect(this.currentUrl, topics);
    } else {
      // No WebSocket URL configured
      this.pushEvent("ws_not_configured", {});
    }
  },

  updated() {
    const nextUrl = this.el.dataset.wsUrl;

    if (this.currentUrl !== nextUrl) {
      this.connect(nextUrl, this.topics);
      this.currentUrl = nextUrl;
    }
  },

  connect(url, topics) {
    if (this._reconnectTimer) {
      clearTimeout(this._reconnectTimer);
      this._reconnectTimer = null;
    }

    if (!url) {
      this.pushEvent("ws_not_configured", {});
      return;
    }

    if (this.ws) {
      this.ws.close();
    }

    const targetUrl = url;

    this.ws = new WebSocket(url);
    this.reconnectAttempts = 0;

    this.ws.onopen = () => {
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
      if (this.currentUrl === targetUrl) {
        const delay = Math.min(1000 * Math.pow(2, this.reconnectAttempts), 30000);
        this.reconnectAttempts++;
        this._reconnectTimer = setTimeout(() => this.connect(targetUrl, topics), delay);
      }
    };

    this.ws.onerror = () => this.ws.close();
  },

  destroyed() {
    if (this._reconnectTimer) clearTimeout(this._reconnectTimer);
    if (this.ws) this.ws.close();
  }
};

export default RiakEvents;
