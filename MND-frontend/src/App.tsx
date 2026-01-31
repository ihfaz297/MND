import { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';

const API_BASE = 'http://localhost:3000/api';

interface Node {
  id: string;
  name: string;
}

interface RouteLeg {
  mode: string;
  from: string;
  to: string;
  departure?: string;
  arrival?: string;
  durationMin?: number;
  route_id?: string;
}

interface RouteOption {
  label: string;
  category: string;
  totalTimeMin: number;
  totalCost: number;
  transfers: number;
  localTimeMin: number;
  localDistanceMeters: number;
  legs: RouteLeg[];
}

function App() {
  const [nodes, setNodes] = useState<Node[]>([]);
  const [from, setFrom] = useState('');
  const [to, setTo] = useState('');
  const [time, setTime] = useState('08:30');
  const [routes, setRoutes] = useState<RouteOption[]>([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    loadNodes();
  }, []);

  const loadNodes = async () => {
    try {
      const res = await axios.get(` ${API_BASE}/nodes` );
      setNodes(res.data.nodes.sort((a: Node, b: Node) => a.name.localeCompare(b.name)));
    } catch (err) {
      console.error('Failed to load nodes:', err);
    }
  };

  const searchRoutes = async () => {
    if (!from || !to) {
      alert('Please select both origin and destination');
      return;
    }

    setLoading(true);
    try {
      const res = await axios.get(` ${API_BASE}/routes` , {
        params: { from, to, time }
      });
      setRoutes(res.data.options || []);
    } catch (err) {
      console.error('Failed to search routes:', err);
      alert('Failed to find routes. Is the backend running?');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="app">
      <div className="container">
        {/* Header */}
        <header className="header">
          <div className="logo">
            <span className="logo-icon"></span>
            <h1 className="logo-text">Sylhet Go</h1>
          </div>
          <p className="tagline">Smart Bus Routing for Sylhet</p>
        </header>

        {/* Search Card */}
        <div className="search-card card">
          <h2 className="card-title">Plan Your Journey</h2>
          
          <div className="form-grid">
            <div className="form-group">
              <label htmlFor="from">From</label>
              <select 
                id="from" 
                value={from} 
                onChange={(e) => setFrom(e.target.value)}
                className="select"
              >
                <option value="">Select origin...</option>
                {nodes.map(node => (
                  <option key={node.id} value={node.id}>{node.name}</option>
                ))}
              </select>
            </div>

            <div className="form-group">
              <label htmlFor="to">To</label>
              <select 
                id="to" 
                value={to} 
                onChange={(e) => setTo(e.target.value)}
                className="select"
              >
                <option value="">Select destination...</option>
                {nodes.map(node => (
                  <option key={node.id} value={node.id}>{node.name}</option>
                ))}
              </select>
            </div>

            <div className="form-group">
              <label htmlFor="time">Departure Time</label>
              <input 
                type="time" 
                id="time" 
                value={time} 
                onChange={(e) => setTime(e.target.value)}
                className="input"
              />
            </div>
          </div>

          <button 
            onClick={searchRoutes} 
            disabled={loading}
            className="btn-primary"
          >
            {loading ? ' Searching...' : ' Find Routes'}
          </button>
        </div>

        {/* Results */}
        <div className="results">
          {loading ? (
            <div className="loading">
              <div className="spinner"></div>
              <p>Finding best routes...</p>
            </div>
          ) : routes.length > 0 ? (
            <>
              <h2 className="results-title">{routes.length} Route{routes.length > 1 ? 's' : ''} Found</h2>
              {routes.map((route, idx) => (
                <div key={idx} className="route-card card">
                  <div className="route-header">
                    <div>
                      <h3 className="route-title">{route.label}</h3>
                      <span className={` adge badge-${route.category}` }>
                        {route.category.toUpperCase()}
                      </span>
                    </div>
                    <div className="route-time">
                      <span className="time-value">{route.totalTimeMin}</span>
                      <span className="time-unit">min</span>
                    </div>
                  </div>

                  <div className="route-stats">
                    <div className="stat">
                      <span className="stat-icon"></span>
                      <span>{route.transfers} transfers</span>
                    </div>
                    <div className="stat">
                      <span className="stat-icon"></span>
                      <span>{route.totalCost}</span>
                    </div>
                    <div className="stat">
                      <span className="stat-icon"></span>
                      <span>{route.localDistanceMeters}m</span>
                    </div>
                  </div>

                  <div className="route-legs">
                    {route.legs.map((leg, legIdx) => (
                      <div key={legIdx} className="leg-container">
                        <div className={` leg leg-${leg.mode}` }>
                          <span className="leg-icon">
                            {leg.mode === 'bus' ? '' : leg.mode === 'walk' ? '' : ''}
                          </span>
                          <div className="leg-info">
                            <div className="leg-route">{leg.from}</div>
                            {leg.departure && (
                              <div className="leg-time">{leg.departure}</div>
                            )}
                          </div>
                        </div>
                        {legIdx < route.legs.length - 1 && (
                          <div className="leg-arrow"></div>
                        )}
                      </div>
                    ))}
                    <div className={` leg leg-${route.legs[route.legs.length - 1].mode}` }>
                      <span className="leg-icon"></span>
                      <div className="leg-info">
                        <div className="leg-route">{route.legs[route.legs.length - 1].to}</div>
                        {route.legs[route.legs.length - 1].arrival && (
                          <div className="leg-time">{route.legs[route.legs.length - 1].arrival}</div>
                        )}
                      </div>
                    </div>
                  </div>
                </div>
              ))}
            </>
          ) : (
            <div className="empty-state">
              <span className="empty-icon"></span>
              <h3>No routes yet</h3>
              <p>Select your origin and destination to find the best routes</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export default App;
