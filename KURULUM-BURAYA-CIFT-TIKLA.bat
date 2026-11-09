@echo off
chcp 65001 >nul
title Sleep Up Kurulum
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0kurulum.ps1"
pause
