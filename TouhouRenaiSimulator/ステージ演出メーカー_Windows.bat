@echo off
cd /d "%~dp0stage_director"
python stage_director_server.py %*
