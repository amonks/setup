#!/usr/bin/env bash

beet convert -y 2>&1 | grep '^convert:' | grep -v 'target file exists'
exit 0

