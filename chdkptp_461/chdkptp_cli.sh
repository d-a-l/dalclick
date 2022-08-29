#!/bin/bash

export LUA_PATH="./lua/?.lua"
export LUA_CPATH="../tecgraf/iup-3.8_Linux32_64_lib/?.so;../tecgraf/cd-5.6.1_Linux32_64_lib/?.so;;"
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:../tecgraf/iup-3.8_Linux32_64_lib:../tecgraf/cd-5.6.1_Linux32_64_lib

./chdkptp

