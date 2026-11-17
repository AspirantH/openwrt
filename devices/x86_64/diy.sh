#!/bin/bash

sed -i 's/Os/O2/g' include/target.mk

sed -i 's/256/1024/g' target/linux/x86/image/Makefile


