const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

app.use(cors());
app.use(express.json());

// In-memory data store
const groups = [
  { id: 'dev-team', name: 'Dev Team', description: 'Engineering channel', members: [] },
  { id: 'general', name: 'General', description: 'Company wide channel', members: [] },
  { id: 'emergency', name: 'Emergency', description: 'Priority communications', members: [] },
];

const MAX_GROUP_SIZE = 20;

// History logs per group
const historyLogs = {
  'dev-team': [],
  'general': [],
  'emergency': []
};

// API Endpoint to get groups
app.get('/api/walkie/groups', (req, res) => {
  res.json({
    success: true,
    data: groups.map(g => ({
      id: g.id,
      name: g.name,
      description: g.description,
      onlineCount: g.members.length
    }))
  });
});

app.post('/api/walkie/groups', (req, res) => {
  const { name, description } = req.body;
  if (!name) return res.status(400).json({ success: false, message: 'Name is required' });
  
  const newGroup = {
    id: name.toLowerCase().replace(/ /g, '-'),
    name,
    description: description || '',
    members: []
  };
  
  // Prevent duplicates
  if (!groups.find(g => g.id === newGroup.id)) {
    groups.push(newGroup);
    historyLogs[newGroup.id] = [];
  }
  
  res.json({ success: true, data: newGroup });
});

app.get('/api/walkie/groups/:groupId/history', (req, res) => {
  const { groupId } = req.params;
  res.json({
    success: true,
    data: historyLogs[groupId] || []
  });
});

io.on('connection', (socket) => {
  console.log('User connected:', socket.id);

  socket.on('walkie:join', (data) => {
    const { groupId, udpPort, localIp, userName, userId } = data;
    
    const group = groups.find(g => g.id === groupId);
    if (!group) return;

    if (group.members.length >= MAX_GROUP_SIZE) {
      socket.emit('walkie:error', { message: 'Group is full (Max 20 members).' });
      return;
    }

    // Add user to group
    const user = { socketId: socket.id, userId: userId || socket.id, name: userName || 'Anonymous', udpIp: localIp, udpPort };
    group.members.push(user);
    socket.join(groupId);
    socket.groupId = groupId; // Store for disconnect

    console.log(`${user.name} joined ${groupId}`);

    // Broadcast updated users
    io.to(groupId).emit('walkie:online_users', group.members);
    
    // Send current history
    socket.emit('walkie:history', historyLogs[groupId] || []);
  });

  socket.on('walkie:ptt_start', (data) => {
    const { groupId, senderName, senderId } = data;
    
    // Log history
    const logEntry = {
      id: Date.now().toString(),
      senderId: senderId || socket.id,
      senderName: senderName || 'Unknown',
      timestamp: new Date().toISOString(),
      action: 'started speaking'
    };
    
    if (historyLogs[groupId]) {
      historyLogs[groupId].push(logEntry);
      if (historyLogs[groupId].length > 50) historyLogs[groupId].shift(); // keep last 50
    }

    io.to(groupId).emit('walkie:ptt_start', {
      senderId: senderId || socket.id,
      senderName,
    });
    
    io.to(groupId).emit('walkie:history', historyLogs[groupId] || []);
  });

  socket.on('walkie:ptt_stop', (data) => {
    const { groupId, senderId, senderName } = data;
    
    const logEntry = {
      id: Date.now().toString(),
      senderId: senderId || socket.id,
      senderName: senderName || 'Unknown',
      timestamp: new Date().toISOString(),
      action: 'stopped speaking'
    };
    
    if (historyLogs[groupId]) {
      historyLogs[groupId].push(logEntry);
      if (historyLogs[groupId].length > 50) historyLogs[groupId].shift(); // keep last 50
    }

    io.to(groupId).emit('walkie:ptt_stop', {
      senderId: senderId || socket.id,
    });
    
    io.to(groupId).emit('walkie:history', historyLogs[groupId] || []);
  });

  socket.on('walkie:leave', (data) => {
    const { groupId } = data;
    leaveGroup(socket, groupId);
  });

  socket.on('disconnect', () => {
    if (socket.groupId) {
      leaveGroup(socket, socket.groupId);
    }
    console.log('User disconnected:', socket.id);
  });
});

function leaveGroup(socket, groupId) {
  const group = groups.find(g => g.id === groupId);
  if (group) {
    group.members = group.members.filter(m => m.socketId !== socket.id);
    io.to(groupId).emit('walkie:online_users', group.members);
  }
  socket.leave(groupId);
}

const PORT = process.env.PORT || 4000;
server.listen(PORT, () => {
  console.log(`VibeCast Separate Backend running on port ${PORT}`);
});
