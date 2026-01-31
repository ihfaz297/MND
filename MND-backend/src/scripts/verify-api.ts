import axios from 'axios';

async function verify(apiKey: string) {
    console.log('Testing Distance Matrix API with provided key...');
    // Use simple known locations
    const origin = 'Sylhet, Bangladesh';
    const dest = 'Dhaka, Bangladesh';
    const url = `https://maps.googleapis.com/maps/api/distancematrix/json?origins=${encodeURIComponent(origin)}&destinations=${encodeURIComponent(dest)}&key=${apiKey}`;

    try {
        const response = await axios.get(url);
        const data = response.data;

        if (data.status === 'OK') {
             // Check specific element status
             const element = data.rows?.[0]?.elements?.[0];
             if (element?.status === 'OK') {
                 console.log('SUCCESS: API Key is valid and Distance Matrix API is enabled.');
                 console.log(`Distance: ${element.distance.text}, Duration: ${element.duration.text}`);
             } else {
                 console.error('FAILURE: API request succeeded, but returned specific error.');
                 console.error('Top-Level Status:', data.status);
                 console.error('Element Status:', element?.status);
                 console.error('Error Message:', data.error_message);
             }
        } else {
            console.error('FAILURE: API returned non-OK status.');
            console.error('Status:', data.status);
            console.error('Error Message:', data.error_message);
        }
    } catch (error: any) {
        console.error('FAILURE: Network request failed.');
        console.error(error.message);
        if (error.response) {
            console.error('Response data:', error.response.data);
        }
    }
}

const key = process.argv[2];
if (!key) {
    console.error('Please provide API key as argument');
    process.exit(1);
}
verify(key);
