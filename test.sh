#!/bin/bash
rm -rf logs/*
# 启动nginx
nginx -p `pwd`/ -c conf/nginx.conf

# 测试路由
# echo "测试 /test 路由:"
# curl http://localhost:8080/test

echo -e "\n测试 /hello 路由:"
curl http://localhost:8080/test
# curl http://localhost:8080/hello

# 停止nginx
nginx -p `pwd`/ -s stop