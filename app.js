const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const bodyParser = require('body-parser');
const path = require('path');

const app = express();
const server = http.createServer(app);
const io = new Server(server);

// Middleware
app.use(bodyParser.json());
app.use(express.static(path.join(__dirname)));

// Device Registration (in-memory store for simplicity)
const devices = [];

app.post('/register', (req, res) => {
  const { deviceName } = req.body;
  const ip = req.ip;
  devices.push({ deviceName, ip });
  res.json({ message: 'Device registered', deviceName, ip });
});

app.get('/devices', (req, res) => {
  res.json(devices);
});

// WebRTC Signaling (Socket.IO)
io.on('connection', (socket) => {
  console.log('New connection:', socket.id);

  socket.on('offer', ({ to, offer }) => {
    io.to(to).emit('offer', { from: socket.id, offer });
  });

  socket.on('answer', ({ to, answer }) => {
    io.to(to).emit('answer', { from: socket.id, answer });
  });

  socket.on('candidate', ({ to, candidate }) => {
    io.to(to).emit('candidate', { from: socket.id, candidate });
  });

  socket.on('disconnect', () => {
    console.log('Connection disconnected:', socket.id);
  });
});

server.listen(3000, () => {
  console.log('Server running on http://localhost:3000');
});