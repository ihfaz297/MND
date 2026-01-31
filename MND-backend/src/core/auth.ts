import crypto from 'crypto';
import fs from 'fs';
import path from 'path';

// ============================================================================
// Types
// ============================================================================

export interface User {
    id: string;
    email: string;
    createdAt: string;
    lastLogin?: string;
}

export interface MagicLinkToken {
    token: string;
    email: string;
    expiresAt: number;
    used: boolean;
}

export interface AuthToken {
    token: string;
    userId: string;
    expiresAt: number;
}

interface UsersData {
    users: User[];
    magicLinks: MagicLinkToken[];
    authTokens: AuthToken[];
}

// ============================================================================
// Auth Manager
// ============================================================================

class AuthManager {
    private dataPath: string;
    private data: UsersData;

    constructor() {
        this.dataPath = path.join(__dirname, '../data/users.json');
        this.data = this.loadData();
    }

    private loadData(): UsersData {
        try {
            if (fs.existsSync(this.dataPath)) {
                const raw = fs.readFileSync(this.dataPath, 'utf-8');
                return JSON.parse(raw);
            }
        } catch (error) {
            console.error('Error loading users data:', error);
        }
        return { users: [], magicLinks: [], authTokens: [] };
    }

    private saveData(): void {
        try {
            fs.writeFileSync(this.dataPath, JSON.stringify(this.data, null, 2));
        } catch (error) {
            console.error('Error saving users data:', error);
        }
    }

    /**
     * Generate a magic link token for email login
     */
    public generateMagicLink(email: string): string {
        // Clean up expired tokens first
        this.cleanupExpiredTokens();

        const token = crypto.randomBytes(32).toString('hex');
        const expiresAt = Date.now() + 15 * 60 * 1000; // 15 minutes

        this.data.magicLinks.push({
            token,
            email: email.toLowerCase(),
            expiresAt,
            used: false
        });

        this.saveData();
        return token;
    }

    /**
     * Verify a magic link token and create auth session
     */
    public verifyMagicLink(token: string): { success: boolean; authToken?: string; user?: User; error?: string } {
        const magicLink = this.data.magicLinks.find(ml => ml.token === token);

        if (!magicLink) {
            return { success: false, error: 'Invalid token' };
        }

        if (magicLink.used) {
            return { success: false, error: 'Token already used' };
        }

        if (Date.now() > magicLink.expiresAt) {
            return { success: false, error: 'Token expired' };
        }

        // Mark token as used
        magicLink.used = true;

        // Find or create user
        let user = this.data.users.find(u => u.email === magicLink.email);
        
        if (!user) {
            user = {
                id: crypto.randomUUID(),
                email: magicLink.email,
                createdAt: new Date().toISOString()
            };
            this.data.users.push(user);
        }

        // Update last login
        user.lastLogin = new Date().toISOString();

        // Generate auth token
        const authToken = crypto.randomBytes(32).toString('hex');
        this.data.authTokens.push({
            token: authToken,
            userId: user.id,
            expiresAt: Date.now() + 7 * 24 * 60 * 60 * 1000 // 7 days
        });

        this.saveData();

        return { success: true, authToken, user };
    }

    /**
     * Validate an auth token and return user
     */
    public validateAuthToken(token: string): User | null {
        const authToken = this.data.authTokens.find(at => at.token === token);

        if (!authToken || Date.now() > authToken.expiresAt) {
            return null;
        }

        return this.data.users.find(u => u.id === authToken.userId) || null;
    }

    /**
     * Get user by ID
     */
    public getUserById(userId: string): User | null {
        return this.data.users.find(u => u.id === userId) || null;
    }

    /**
     * Logout - invalidate auth token
     */
    public logout(token: string): void {
        this.data.authTokens = this.data.authTokens.filter(at => at.token !== token);
        this.saveData();
    }

    /**
     * Clean up expired tokens
     */
    private cleanupExpiredTokens(): void {
        const now = Date.now();
        this.data.magicLinks = this.data.magicLinks.filter(ml => !ml.used && ml.expiresAt > now);
        this.data.authTokens = this.data.authTokens.filter(at => at.expiresAt > now);
    }
}

export const authManager = new AuthManager();
