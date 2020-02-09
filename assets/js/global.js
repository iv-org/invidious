// Disable Web Workers. Fixes Video.js CSP violation (created by `new Worker(objURL)`):
// Refused to create a worker from 'blob:http://host/id' because it violates the following Content Security Policy directive: "worker-src 'self'".
window.Worker = undefined;
