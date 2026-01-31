import { Request, Response } from 'express';
import { graph } from '../core/graph';
import { parseTime, timeToMinutes, minutesToTime } from '../core/types';

// ============================================================================
// Types
// ============================================================================

interface UpcomingBus {
    routeId: string;
    routeName: string;
    tripId: string;
    departure: string;
    minutesUntil: number;
    destination: string;
    direction: string;
    stopsAway: number;
}

// ============================================================================
// Controllers
// ============================================================================

/**
 * GET /api/buses/upcoming
 * Get upcoming buses from a specific location
 * 
 * Query params:
 * - from: origin node ID (required)
 * - to: destination node ID (optional, filters by routes that go there)
 * - limit: max results (default: 5, max: 20)
 * - time: current time in HH:MM (default: now)
 */
export async function getUpcomingBuses(req: Request, res: Response): Promise<void> {
    try {
        const { from, to, limit: limitStr, time: requestTime } = req.query;

        // Validation
        if (!from || typeof from !== 'string') {
            res.status(400).json({
                error: 'Missing origin',
                message: 'Please provide "from" parameter'
            });
            return;
        }

        // Verify node exists
        if (!graph.hasNode(from)) {
            res.status(404).json({
                error: 'Invalid location',
                message: `Location "${from}" not found`
            });
            return;
        }

        // Parse limit
        let limit = parseInt(limitStr as string) || 5;
        limit = Math.min(Math.max(limit, 1), 20); // Clamp between 1-20

        // Get current time
        const now = new Date();
        const currentTime = requestTime 
            ? String(requestTime) 
            : `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;
        
        const currentMinutes = timeToMinutes(parseTime(currentTime));

        // Find upcoming buses
        const upcomingBuses: UpcomingBus[] = [];
        const routes = graph.getAllRoutes();

        for (const route of routes) {
            for (const trip of route.trips) {
                const stopIndex = trip.stops.indexOf(from);
                
                // Skip if this trip doesn't serve this stop
                if (stopIndex === -1) continue;

                // If destination specified, check if trip goes there
                if (to && typeof to === 'string') {
                    const toIndex = trip.stops.indexOf(to);
                    // Skip if doesn't serve destination or destination is before origin
                    if (toIndex === -1 || toIndex <= stopIndex) continue;
                }

                // Calculate when bus arrives at this stop
                const tripStartMinutes = timeToMinutes(parseTime(trip.departure_time));
                const avgTimePerStop = 5; // 5 minutes average per stop
                const arrivalAtStopMinutes = tripStartMinutes + (stopIndex * avgTimePerStop);

                // Calculate minutes until arrival
                let minutesUntil = arrivalAtStopMinutes - currentMinutes;

                // Handle next day (if negative, bus already passed)
                if (minutesUntil < -30) {
                    // This trip was earlier today, skip
                    continue;
                }

                // If just slightly negative, bus might be arriving now
                if (minutesUntil < 0) {
                    minutesUntil = 0;
                }

                // Only show buses within next 2 hours
                if (minutesUntil > 120) continue;

                // Determine destination (last stop of trip)
                const finalStop = trip.stops[trip.stops.length - 1];

                upcomingBuses.push({
                    routeId: route.route_id,
                    routeName: route.name,
                    tripId: trip.trip_id,
                    departure: minutesToTime(arrivalAtStopMinutes),
                    minutesUntil,
                    destination: finalStop,
                    direction: trip.direction,
                    stopsAway: stopIndex
                });
            }
        }

        // Sort by minutes until arrival
        upcomingBuses.sort((a, b) => a.minutesUntil - b.minutesUntil);

        // Limit results
        const limitedBuses = upcomingBuses.slice(0, limit);

        // Get node name for response
        const fromNode = graph.getNode(from);

        res.json({
            location: {
                id: from,
                name: fromNode?.name || from
            },
            currentTime,
            count: limitedBuses.length,
            buses: limitedBuses.map(bus => ({
                route_id: bus.routeId,
                route_name: bus.routeName,
                trip_id: bus.tripId,
                departure: bus.departure,
                minutesUntil: bus.minutesUntil,
                destination: bus.destination,
                direction: bus.direction,
                status: bus.minutesUntil === 0 
                    ? 'arriving' 
                    : bus.minutesUntil <= 5 
                        ? 'soon' 
                        : 'scheduled'
            }))
        });
    } catch (error: any) {
        console.error('Error getting upcoming buses:', error);
        res.status(500).json({
            error: 'Failed to get upcoming buses',
            message: error.message
        });
    }
}

/**
 * GET /api/buses/schedule/:routeId
 * Get full schedule for a specific route
 */
export async function getRouteSchedule(req: Request, res: Response): Promise<void> {
    try {
        const { routeId } = req.params;

        if (!routeId) {
            res.status(400).json({
                error: 'Missing route ID',
                message: 'Please provide route ID'
            });
            return;
        }

        const routes = graph.getAllRoutes();
        const route = routes.find(r => r.route_id === routeId);

        if (!route) {
            res.status(404).json({
                error: 'Route not found',
                message: `Route "${routeId}" not found`
            });
            return;
        }

        res.json({
            route_id: route.route_id,
            name: route.name,
            trips: route.trips.map(trip => ({
                trip_id: trip.trip_id,
                direction: trip.direction,
                departure_time: trip.departure_time,
                stops: trip.stops,
                stop_count: trip.stops.length
            }))
        });
    } catch (error: any) {
        console.error('Error getting route schedule:', error);
        res.status(500).json({
            error: 'Failed to get schedule',
            message: error.message
        });
    }
}

/**
 * GET /api/routes/:routeId
 * Get detailed route information
 */
export async function getRouteDetails(req: Request, res: Response): Promise<void> {
    try {
        const { routeId } = req.params;

        if (!routeId) {
            res.status(400).json({
                error: 'Missing route ID',
                message: 'Please provide route ID'
            });
            return;
        }

        const routes = graph.getAllRoutes();
        const route = routes.find(r => r.route_id === routeId);

        if (!route) {
            res.status(404).json({
                error: 'Route not found',
                message: `Route "${routeId}" not found`
            });
            return;
        }

        // Get all unique stops on this route
        const allStops = new Set<string>();
        route.trips.forEach(trip => {
            trip.stops.forEach(stop => allStops.add(stop));
        });

        // Get node details for each stop
        const stopsWithDetails = Array.from(allStops).map(stopId => {
            const node = graph.getNode(stopId);
            return {
                id: stopId,
                name: node?.name || stopId,
                type: node?.type || 'unknown'
            };
        });

        res.json({
            route_id: route.route_id,
            name: route.name,
            total_trips: route.trips.length,
            stops: stopsWithDetails,
            trips: route.trips.map(trip => ({
                trip_id: trip.trip_id,
                direction: trip.direction,
                departure_time: trip.departure_time,
                stops: trip.stops
            }))
        });
    } catch (error: any) {
        console.error('Error getting route details:', error);
        res.status(500).json({
            error: 'Failed to get route details',
            message: error.message
        });
    }
}
