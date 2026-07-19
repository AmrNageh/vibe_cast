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
// A group now has: id, name, description, ownerId, permanentMembers (array of userIds), activeMembers (array of socket users)
const groups = [];

const MAX_GROUP_SIZE = 20;

// History logs per group (Voice logs)
const historyLogs = {};
// Chat messages per group
const chatLogs = {};

// API Endpoint to get groups for a specific user
app.get('/api/walkie/groups', (req, res) => {
  const userId = req.query.userId;
  if (!userId) {
    return res.status(400).json({ success: false, message: 'userId is required to fetch groups' });
  }

  // Find groups where the user is a permanent member
  const userGroups = groups.filter(g => g.permanentMembers.includes(userId));

  res.json({
    success: true,
    data: userGroups.map(g => ({
      id: g.id,
      name: g.name,
      description: g.description,
      onlineCount: g.activeMembers.length,
      ownerId: g.ownerId,
      permanentMembers: g.permanentMembers
    }))
  });
});

// Create a new group
app.post('/api/walkie/groups', (req, res) => {
  const { name, description, userId } = req.body;
  if (!name || !userId) return res.status(400).json({ success: false, message: 'Name and userId are required' });
  
  const newGroup = {
    id: Date.now().toString(36) + Math.random().toString(36).substr(2, 5), // Unique ID for invite link
    name,
    description: description || '',
    ownerId: userId,
    permanentMembers: [userId],
    activeMembers: []
  };
  
  groups.push(newGroup);
  historyLogs[newGroup.id] = [];
  chatLogs[newGroup.id] = [];
  
  res.json({ success: true, data: newGroup });
});

// Join a group via invite link (groupId)
app.post('/api/walkie/groups/join', (req, res) => {
  const { groupId, userId } = req.body;
  if (!groupId || !userId) return res.status(400).json({ success: false, message: 'groupId and userId are required' });

  const group = groups.find(g => g.id === groupId);
  if (!group) return res.status(404).json({ success: false, message: 'Group not found or invalid invite link' });

  if (!group.permanentMembers.includes(userId)) {
    group.permanentMembers.push(userId);
  }

  res.json({ success: true, data: group });
});

// Get voice history
app.get('/api/walkie/groups/:groupId/history', (req, res) => {
  const { groupId } = req.params;
  res.json({
    success: true,
    data: historyLogs[groupId] || []
  });
});

// Get chat history
app.get('/api/walkie/groups/:groupId/chat', (req, res) => {
  const { groupId } = req.params;
  res.json({
    success: true,
    data: chatLogs[groupId] || []
  });
});

io.on('connection', (socket) => {
  console.log('User connected:', socket.id);

  socket.on('walkie:join', (data) => {
    const { groupId, udpPort, localIp, userName, userId } = data;
    
    const group = groups.find(g => g.id === groupId);
    if (!group) return;

    if (group.activeMembers.length >= MAX_GROUP_SIZE) {
      socket.emit('walkie:error', { message: 'Group is full (Max 20 members).' });
      return;
    }

    // Auto-add to permanent members if not already (safeguard)
    if (userId && !group.permanentMembers.includes(userId)) {
      group.permanentMembers.push(userId);
    }

    // Add user to active members
    const user = { socketId: socket.id, userId: userId || socket.id, name: userName || 'Anonymous', udpIp: localIp, udpPort };
    group.activeMembers.push(user);
    socket.join(groupId);
    socket.groupId = groupId; // Store for disconnect

    console.log(`${user.name} joined ${groupId}`);

    // Broadcast updated users
    io.to(groupId).emit('walkie:online_users', group.activeMembers);
    
    // Send current histories
    socket.emit('walkie:history', historyLogs[groupId] || []);
    socket.emit('walkie:chat_history', chatLogs[groupId] || []);
  });

  socket.on('walkie:chat_message', (data) => {
    const { groupId, senderId, senderName, message } = data;
    
    const chatEntry = {
      id: Date.now().toString(),
      senderId: senderId || socket.id,
      senderName: senderName || 'Unknown',
      message: message,
      timestamp: new Date().toISOString()
    };

    if (!chatLogs[groupId]) chatLogs[groupId] = [];
    chatLogs[groupId].push(chatEntry);
    if (chatLogs[groupId].length > 100) chatLogs[groupId].shift(); // keep last 100 messages

    io.to(groupId).emit('walkie:chat_message', chatEntry);
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
    
    if (!historyLogs[groupId]) historyLogs[groupId] = [];
    historyLogs[groupId].push(logEntry);
    if (historyLogs[groupId].length > 50) historyLogs[groupId].shift(); 

    io.to(groupId).emit('walkie:ptt_start', {
      senderId: senderId || socket.id,
      senderName,
    });
    
    io.to(groupId).emit('walkie:history', historyLogs[groupId]);
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
    
    if (!historyLogs[groupId]) historyLogs[groupId] = [];
    historyLogs[groupId].push(logEntry);
    if (historyLogs[groupId].length > 50) historyLogs[groupId].shift(); 

    io.to(groupId).emit('walkie:ptt_stop', {
      senderId: senderId || socket.id,
    });
    
    io.to(groupId).emit('walkie:history', historyLogs[groupId]);
  });

  socket.on('walkie:leave', (data) => {
    const { groupId } = data;
    leaveGroup(socket, groupId);
  });

  socket.on('walkie:audio', (data) => {
    // data should contain { groupId, senderId, audioBlob }
    const { groupId, senderId, audioBlob } = data;
    // Broadcast to everyone else in the group
    socket.to(groupId).emit('walkie:audio', {
      senderId: senderId || socket.id,
      audioBlob: audioBlob
    });
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
    group.activeMembers = group.activeMembers.filter(m => m.socketId !== socket.id);
    io.to(groupId).emit('walkie:online_users', group.activeMembers);
  }
  socket.leave(groupId);
}

const PORT = process.env.PORT || 4000;
server.listen(PORT, '0.0.0.0', () => {
  console.log(`VibeCast Separate Backend running on port ${PORT}`);
});
