
import { graph } from '../core/graph';

async function main() {
    // Silence valid logs
    const originalLog = console.log;
    console.log = () => { };

    graph.loadData();

    const candidates = ['MODINA_MARKET', 'SUBIDBAZAR', 'RIKABI_BAZAR'];
    const to = 'LAMABAZAR';
    const results: any = {};

    for (const from of candidates) {
        const path = graph.localShortestPath(from, to);
        results[from] = path.found ? { time: path.totalTime, cost: path.totalCost } : 'No Path';
    }

    // Restore log for final output
    console.log = originalLog;
    console.log(JSON.stringify(results, null, 2));
}

main();
