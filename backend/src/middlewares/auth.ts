import { Request, Response, NextFunction } from 'express';
import { supabase } from '../utils/supabaseClient';

interface AuthenticatedRequest extends Request {
  user?: {
    id: string;
    role: string;
  };
}

export const authMiddleware = async (
  req: AuthenticatedRequest,
  res: Response,
  next: NextFunction
) => {
  const authHeader = req.headers.authorization;
  if (!authHeader) {
    return res.status(401).json({ success: false, error: 'Missing auth token' });
  }
  const token = authHeader.replace(/^Bearer\s+/i, '');
  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data.user) {
    return res.status(401).json({ success: false, error: 'Invalid token' });
  }
  req.user = {
    id: data.user.id,
    role: (data.user.app_metadata?.role as string) || 'user',
  };
  next();
};
