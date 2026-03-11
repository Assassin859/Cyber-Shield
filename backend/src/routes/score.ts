import { Router } from 'express';
import { scoreController } from '../controllers/scoreController';
import { authMiddleware } from '../middlewares/auth';

const router = Router();

// public endpoint (auth optional?) we'll require auth for now
router.post('/', authMiddleware, scoreController);

export default router;
