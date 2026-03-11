import express from 'express';
import bodyParser from 'body-parser';
import scoreRoute from './routes/score';

const app = express();
app.use(bodyParser.json());

app.get('/', (req, res) => res.send('CyberShield backend running'));

// feature routes
app.use('/api/score', scoreRoute);

const port = process.env.PORT || 3000;
app.listen(port, () => {
  console.log(`Server listening on ${port}`);
});
