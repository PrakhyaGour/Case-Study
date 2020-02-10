apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-v1
  namespace: case-study
  annotations:
    flux.weave.works/automated: "true"
    flux.weave.works/tag.hello: regexp:^((?!tmp).)*$
  labels:
    app: hello-v1
spec:
  selector:
    matchLabels:
      app: hello-v1
  template:
    metadata:
      labels:
        app: hello-v1
    spec:
      containers:
      - name: hello-v1
        image: 513293136839.dkr.ecr.ap-south-1.amazonaws.com/hello:GIT_COMMIT
