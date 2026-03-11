import { Request, Response } from 'express';
import { scoreRecipient } from '../services/scoreService';

export const scoreController = async (req: Request, res: Response) => {
  const { value } = req.body as { value?: string };
  if (!value) {
    return res.status(400).json({ success: false, error: 'value is required' });
  }

  try {
    const result = await scoreRecipient(value);
    return res.json({ success: true, data: result });
  } catch (err: any) {
    console.error('score error', err);
    return res.status(500).json({ success: false, error: 'internal' });
  }
};
