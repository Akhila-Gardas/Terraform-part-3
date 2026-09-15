const express = require('express');
const app = express();
app.get('/', (req,res) => res.send('<h1>Express on ECS Fargate - Part 3 SUCCESS</h1>'));
app.listen(3000,'0.0.0.0', () => console.log('Express 3000'));