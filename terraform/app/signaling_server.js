const WebSocket = require("ws");

const server = new WebSocket.Server({ port: 8080 });
let connectedDevices = [];

server.on("connection", (socket) => {
  socket.on("message", (message) => {
    const data = JSON.parse(message);

    if (data.type === "register") {
      connectedDevices.push({ id: data.id, name: data.name, socket });
      broadcastDevices();
    }

    socket.on("close", () => {
      connectedDevices = connectedDevices.filter((d) => d.socket !== socket);
      broadcastDevices();
    });
  });
});

function broadcastDevices() {
  const deviceList = connectedDevices.map((device) => ({ id: device.id, name: device.name }));
  connectedDevices.forEach((device) => {
    device.socket.send(JSON.stringify({ type: "deviceList", devices: deviceList }));
  });
}

console.log("Signaling server running on ws://0.0.0.0:8080");
