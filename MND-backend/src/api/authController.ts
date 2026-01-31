import { Request, Response } from 'express';
import { authManager } from '../core/auth';

/**
 * POST /api/auth/send-link
 * Send magic login link to email
 */
export async function sendMagicLink(req: Request, res: Response): Promise<void> {
    try {
        const { email } = req.body;

        if (!email || typeof email !== 'string') {
            res.status(400).json({
                error: 'Email is required',
                message: 'Please provide a valid email address'
            });
            return;
        }

        // Basic email validation
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(email)) {
            res.status(400).json({
                error: 'Invalid email',
                message: 'Please provide a valid email address'
            });
            return;
        }

        const token = authManager.generateMagicLink(email);

        // In production, you'd send this via email service
        // For now, we'll return it (for testing) and log it
        const magicLinkUrl = `${req.protocol}://${req.get('host')}/api/auth/verify?token=${token}`;

        console.log(`\n📧 Magic Link Generated`);
        console.log(`   Email: ${email}`);
        console.log(`   Link: ${magicLinkUrl}`);
        console.log(`   Token: ${token}`);
        console.log(`   Expires in: 15 minutes\n`);

        res.json({
            success: true,
            message: 'Magic link sent to your email',
            // DEV ONLY: Remove in production
            _dev: {
                note: 'In production, this token would be sent via email only',
                token,
                verifyUrl: magicLinkUrl
            }
        });
    } catch (error: any) {
        console.error('Error sending magic link:', error);
        res.status(500).json({
            error: 'Failed to send magic link',
            message: error.message
        });
    }
}

/**
 * GET /api/auth/verify
 * Verify magic link token and create session
 */
export async function verifyMagicLink(req: Request, res: Response): Promise<void> {
    try {
        const { token } = req.query;

        if (!token || typeof token !== 'string') {
            res.status(400).json({
                error: 'Token is required',
                message: 'Please provide a valid token'
            });
            return;
        }

        const result = authManager.verifyMagicLink(token);

        if (!result.success) {
            res.status(401).json({
                error: 'Verification failed',
                message: result.error
            });
            return;
        }

        console.log(`\n✓ User logged in: ${result.user?.email}\n`);

        res.json({
            success: true,
            message: 'Login successful',
            authToken: result.authToken,
            user: {
                id: result.user?.id,
                email: result.user?.email,
                createdAt: result.user?.createdAt,
                lastLogin: result.user?.lastLogin
            }
        });
    } catch (error: any) {
        console.error('Error verifying magic link:', error);
        res.status(500).json({
            error: 'Verification failed',
            message: error.message
        });
    }
}

/**
 * GET /api/profile
 * Get authenticated user profile
 */
export async function getProfile(req: Request, res: Response): Promise<void> {
    try {
        const authHeader = req.headers.authorization;

        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            res.status(401).json({
                error: 'Unauthorized',
                message: 'Please provide a valid auth token'
            });
            return;
        }

        const token = authHeader.substring(7); // Remove 'Bearer '
        const user = authManager.validateAuthToken(token);

        if (!user) {
            res.status(401).json({
                error: 'Unauthorized',
                message: 'Invalid or expired token'
            });
            return;
        }

        res.json({
            user: {
                id: user.id,
                email: user.email,
                createdAt: user.createdAt,
                lastLogin: user.lastLogin
            }
        });
    } catch (error: any) {
        console.error('Error getting profile:', error);
        res.status(500).json({
            error: 'Failed to get profile',
            message: error.message
        });
    }
}

/**
 * POST /api/auth/logout
 * Logout and invalidate token
 */
export async function logout(req: Request, res: Response): Promise<void> {
    try {
        const authHeader = req.headers.authorization;

        if (authHeader && authHeader.startsWith('Bearer ')) {
            const token = authHeader.substring(7);
            authManager.logout(token);
        }

        res.json({
            success: true,
            message: 'Logged out successfully'
        });
    } catch (error: any) {
        console.error('Error logging out:', error);
        res.status(500).json({
            error: 'Logout failed',
            message: error.message
        });
    }
}

/**
 * Middleware: Extract user from auth token (optional auth)
 */
export function optionalAuth(req: Request, res: Response, next: Function): void {
    const authHeader = req.headers.authorization;

    if (authHeader && authHeader.startsWith('Bearer ')) {
        const token = authHeader.substring(7);
        const user = authManager.validateAuthToken(token);
        if (user) {
            (req as any).user = user;
            (req as any).authToken = token;
        }
    }

    next();
}

/**
 * Middleware: Require authentication
 */
export function requireAuth(req: Request, res: Response, next: Function): void {
    const authHeader = req.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        res.status(401).json({
            error: 'Unauthorized',
            message: 'Authentication required'
        });
        return;
    }

    const token = authHeader.substring(7);
    const user = authManager.validateAuthToken(token);

    if (!user) {
        res.status(401).json({
            error: 'Unauthorized',
            message: 'Invalid or expired token'
        });
        return;
    }

    (req as any).user = user;
    (req as any).authToken = token;
    next();
}
