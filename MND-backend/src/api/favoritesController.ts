import { Request, Response } from 'express';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';

// ============================================================================
// Types
// ============================================================================

export interface Favorite {
    id: string;
    userId: string;
    label: string;
    from: string;
    to: string;
    defaultTime: string;
    createdAt: string;
}

interface FavoritesData {
    favorites: Favorite[];
}

// ============================================================================
// Data Management
// ============================================================================

const dataPath = path.join(__dirname, '../data/favorites.json');

function loadFavorites(): FavoritesData {
    try {
        if (fs.existsSync(dataPath)) {
            const raw = fs.readFileSync(dataPath, 'utf-8');
            return JSON.parse(raw);
        }
    } catch (error) {
        console.error('Error loading favorites:', error);
    }
    return { favorites: [] };
}

function saveFavorites(data: FavoritesData): void {
    try {
        fs.writeFileSync(dataPath, JSON.stringify(data, null, 2));
    } catch (error) {
        console.error('Error saving favorites:', error);
    }
}

// ============================================================================
// Controllers
// ============================================================================

/**
 * GET /api/favorites
 * Get all favorites for authenticated user
 */
export async function getFavorites(req: Request, res: Response): Promise<void> {
    try {
        const user = (req as any).user;

        if (!user) {
            res.status(401).json({
                error: 'Unauthorized',
                message: 'Authentication required'
            });
            return;
        }

        const data = loadFavorites();
        const userFavorites = data.favorites.filter(f => f.userId === user.id);

        res.json({
            count: userFavorites.length,
            favorites: userFavorites.map(f => ({
                id: f.id,
                label: f.label,
                from: f.from,
                to: f.to,
                defaultTime: f.defaultTime,
                createdAt: f.createdAt
            }))
        });
    } catch (error: any) {
        console.error('Error getting favorites:', error);
        res.status(500).json({
            error: 'Failed to get favorites',
            message: error.message
        });
    }
}

/**
 * POST /api/favorites
 * Create a new favorite route
 */
export async function createFavorite(req: Request, res: Response): Promise<void> {
    try {
        const user = (req as any).user;

        if (!user) {
            res.status(401).json({
                error: 'Unauthorized',
                message: 'Authentication required'
            });
            return;
        }

        const { label, from, to, defaultTime } = req.body;

        // Validation
        if (!label || !from || !to) {
            res.status(400).json({
                error: 'Missing required fields',
                message: 'Please provide label, from, and to'
            });
            return;
        }

        const data = loadFavorites();

        // Check for duplicates
        const duplicate = data.favorites.find(
            f => f.userId === user.id && f.from === from && f.to === to
        );

        if (duplicate) {
            res.status(409).json({
                error: 'Duplicate favorite',
                message: 'This route is already saved',
                existing: {
                    id: duplicate.id,
                    label: duplicate.label
                }
            });
            return;
        }

        // Check limit (max 10 favorites per user)
        const userFavorites = data.favorites.filter(f => f.userId === user.id);
        if (userFavorites.length >= 10) {
            res.status(400).json({
                error: 'Limit reached',
                message: 'Maximum 10 favorites allowed. Please delete some to add more.'
            });
            return;
        }

        const favorite: Favorite = {
            id: crypto.randomUUID(),
            userId: user.id,
            label,
            from,
            to,
            defaultTime: defaultTime || '08:00',
            createdAt: new Date().toISOString()
        };

        data.favorites.push(favorite);
        saveFavorites(data);

        console.log(`\n⭐ Favorite saved: ${label} (${from} → ${to}) for ${user.email}\n`);

        res.status(201).json({
            success: true,
            message: 'Favorite saved',
            favorite: {
                id: favorite.id,
                label: favorite.label,
                from: favorite.from,
                to: favorite.to,
                defaultTime: favorite.defaultTime,
                createdAt: favorite.createdAt
            }
        });
    } catch (error: any) {
        console.error('Error creating favorite:', error);
        res.status(500).json({
            error: 'Failed to save favorite',
            message: error.message
        });
    }
}

/**
 * DELETE /api/favorites/:id
 * Delete a favorite route
 */
export async function deleteFavorite(req: Request, res: Response): Promise<void> {
    try {
        const user = (req as any).user;

        if (!user) {
            res.status(401).json({
                error: 'Unauthorized',
                message: 'Authentication required'
            });
            return;
        }

        const { id } = req.params;

        if (!id) {
            res.status(400).json({
                error: 'Missing ID',
                message: 'Please provide favorite ID'
            });
            return;
        }

        const data = loadFavorites();
        const favoriteIndex = data.favorites.findIndex(
            f => f.id === id && f.userId === user.id
        );

        if (favoriteIndex === -1) {
            res.status(404).json({
                error: 'Not found',
                message: 'Favorite not found or does not belong to you'
            });
            return;
        }

        const deleted = data.favorites.splice(favoriteIndex, 1)[0];
        saveFavorites(data);

        console.log(`\n🗑️ Favorite deleted: ${deleted.label} for ${user.email}\n`);

        res.json({
            success: true,
            message: 'Favorite deleted',
            deleted: {
                id: deleted.id,
                label: deleted.label
            }
        });
    } catch (error: any) {
        console.error('Error deleting favorite:', error);
        res.status(500).json({
            error: 'Failed to delete favorite',
            message: error.message
        });
    }
}

/**
 * PUT /api/favorites/:id
 * Update a favorite route
 */
export async function updateFavorite(req: Request, res: Response): Promise<void> {
    try {
        const user = (req as any).user;

        if (!user) {
            res.status(401).json({
                error: 'Unauthorized',
                message: 'Authentication required'
            });
            return;
        }

        const { id } = req.params;
        const { label, defaultTime } = req.body;

        if (!id) {
            res.status(400).json({
                error: 'Missing ID',
                message: 'Please provide favorite ID'
            });
            return;
        }

        const data = loadFavorites();
        const favorite = data.favorites.find(
            f => f.id === id && f.userId === user.id
        );

        if (!favorite) {
            res.status(404).json({
                error: 'Not found',
                message: 'Favorite not found or does not belong to you'
            });
            return;
        }

        // Update fields
        if (label) favorite.label = label;
        if (defaultTime) favorite.defaultTime = defaultTime;

        saveFavorites(data);

        res.json({
            success: true,
            message: 'Favorite updated',
            favorite: {
                id: favorite.id,
                label: favorite.label,
                from: favorite.from,
                to: favorite.to,
                defaultTime: favorite.defaultTime,
                createdAt: favorite.createdAt
            }
        });
    } catch (error: any) {
        console.error('Error updating favorite:', error);
        res.status(500).json({
            error: 'Failed to update favorite',
            message: error.message
        });
    }
}
