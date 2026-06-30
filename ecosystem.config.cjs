module.exports = {
  apps: [
    {
      name: 'isoo',
      script: 'bundle',
      args: 'exec puma -C config/puma.rb',
      cwd: '/app',
      interpreter: 'none',
      exec_mode: 'fork',
      instances: 1,
      autorestart: true,
      max_restarts: 10,
      min_uptime: '5s',
      kill_timeout: 5000,
      env: {
        PORT: '9292',
        BIND: '0.0.0.0',
        RACK_ENV: process.env.RACK_ENV || 'development',
      },
    },
  ],
};
