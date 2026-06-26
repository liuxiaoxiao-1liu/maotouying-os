#!/bin/bash
sg docker -c "docker run --rm --privileged --network=host \
  -v /home/liuxiaoxiao/文件/操作系统/output:/build/output \
  -v /home/liuxiaoxiao/文件/操作系统/scripts:/build/scripts:ro \
  maotouying-build bash /build/scripts/build-iso.sh"
