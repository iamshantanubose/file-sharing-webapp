const http = require('http');

const websiteUrl = process.env.WEBSITE_URL;

if (!websiteUrl) {
  console.error("Error: WEBSITE_URL environment variable is not set.");
  process.exit(1);
}

http.get(websiteUrl, (res) => {
  if (res.statusCode === 200) {
    console.log(`Website is reachable: ${websiteUrl}`);
    process.exit(0);
  } else {
    console.error(`Website is not reachable. Status Code: ${res.statusCode}`);
    process.exit(1);
  }
}).on('error', (err) => {
  console.error(`Error connecting to website: ${err.message}`);
  process.exit(1);
});
