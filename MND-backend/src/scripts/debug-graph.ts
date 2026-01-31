
import { graph } from '../core/graph';

async function main() {
    console.log('Loading graph...');
    graph.loadData();

    console.log('Nodes:', graph.getAllNodes().length);
    // console.log('Edges for SHIBGONJ:', graph.getNeighbors('SHIBGONJ'));

    const from = 'SHIBGONJ';
    const to = 'LAMABAZAR';

    console.log(`\nTesting Local Path: ${from} -> ${to}`);
    const path = graph.localShortestPath(from, to);

    console.log('Path Result:', JSON.stringify(path, null, 2));

    if (path.found) {
        console.log('SUCCESS: Path found');
    } else {
        console.log('FAILURE: No path found');
        const neighbors = graph.getNeighbors(from);
        console.log('Neighbors of SHIBGONJ:', neighbors.map(n => `${n.to} (${n.mode})`));
    }
}

main();
