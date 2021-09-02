#!/bin/bash

cd assets 
rm -rf node_modules/
npm install
cd ..
mix deps.get
mix phx.server

