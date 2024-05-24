#!/bin/bash

# Kill any running Puma processes
pkill -f puma

# Kill any running Foreman processes
pkill -f foreman

# Start Puma in the background
bundle exec puma -C config/puma.rb &

# Start Foreman in the background
foreman start -f Procfile.dev.sidekiq-webpack &

# Wait for all background processes to finish
wait

