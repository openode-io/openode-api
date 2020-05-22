#!/usr/bin/env node

const http = require("http");

const server = http.createServer(function (req, res) {
  console.log(`server is up! :-)`, req.url)

  if (req.url === '/status') {
    res.end("Hello /status");

  }
  else if (req.url === '/status2') {

  } else {
    res.end(`Hello pretty opeNode World ${process.env.TEST}`);
  }
}).listen(80, (err) => {
  if ( ! err) {
    console.log(`node server listening on port 80...${process.env.TEST}`)
  }
})
