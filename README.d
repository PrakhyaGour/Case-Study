What is GitOps?

GitOps is a way to do Kubernetes cluster management and application delivery.  It works by using Git as a single source of truth for declarative infrastructure and applications. With Git at the center of your delivery pipelines, developers can make pull requests to accelerate and simplify application deployments and operations tasks to Kubernetes.In this case study flux will be used to perform the gitops making it single source of truth.

What is Flux?

Flux enables continuous delivery of container images, using version control for each step to ensure deployment is reproducible, auditable and revertible. Deploy code as fast as your team creates it, confident that you can easily revert if required.

We believe in GitOps:
1-Git as the single source of truth 
2-Git as the single place where we operate all environments 
3-All changes are observable/verifiable 

Prerequisites:
-AWS account
-EKS cluster created
-Jenkins Server
-A workstation 
-awscli
-kubectl
-helm

Implementing Gitops:
Application:
I have created a simple flask hello world application(app.py) and in turn creating a docker image of the same to deploy in the kubernetes using a Dockerfile.All the requirement to run the application is present in reuirement.txt.
in operating model for building cloud native applications

Kubernetes Setup:
I assume you have eks/anyk8s cluster setup in place.We have two yaml files defining the deployment and service for the application.I have used loadbalancer service for the same.
You can switch the k8s context to your own eks cluster and deploy the above files to get the deployment done.

Jenkins Setup:
Implementing Gitops, I am using jenkins as a CI tool which gets triggered and pulls the git repo whenever any changes are commited to the repo and build the image of the application and change the deployement file with the genereated tag and push the changed files back to the git repo.We are pushing the files back so that we have only single source of truth about the infrastructure as well as the code.
Whenever developer commites the code with/without the PRs in place,a job will automatially gets triggered and perform the code changes,encapsulate the same in a docker image, change the k8s config accordingly and push the same on the git back.
This makes the config and code well updated in the single source of truth
Steps:
-Setup a freestyle job with webhook to git repo enabled.
-Your jenkins config should looks like
-----------------------------------------------------------------------------------------------------
#Docker image build
tag=$(git log --format="%H" -n 1)
docker build --no-cache  -t hello:$tag .
docker tag hello:$tag 513293136839.dkr.ecr.ap-south-1.amazonaws.com/hello:$tag
$(~/.local/bin/aws ecr get-login --no-include-email --region ap-south-1)
#pushing the image to ECR repo
docker push 513293136839.dkr.ecr.ap-south-1.amazonaws.com/hello:$tag 
cat k8s/deploy.tpl | sed 's/GIT_COMMIT/'"$tag/" > k8s/deploy.yml 
git checkout master 
git pull origin master
git add .
git commit -m "Image upgrade" 
#setup your remote origin
git remote set-url origin git@github.com:PrakhyaGour/Case-Study.git
git push origin master 
-------------------------------------------------------------------------------------------------------
Flux Setup:
Here I am using helm to install flux in my k8s system.
Steps:
-Add the Flux repo:
 helm repo add fluxcd https://charts.fluxcd.io
-Create the flux namespace:
 kubectl create namespace flux
-Replace fluxcd/flux-get-started with your own git repository and run helm install:
 helm upgrade -i flux fluxcd/flux --set git.url=git@github.com:fluxcd/flux-get-started --namespace flux
-Get the public keys:
 fluxctl identity --k8s-fwd-ns flux
-In order to sync your cluster state with GitHub you need to copy the public key and create a deploy key with access on your GitHub repository. Go to Settings > Deploy keys click on Add deploy key, paste the Flux public key and click Add key. If you want Flux to have write access to your repo, check Allow write access; if you have set git.readonly=true, you can leave this box unchecked.

Whenever there is any yaml config change in git repo, flux controller(which is running as a pod in flux namespace) will compare the yaml of the deployment in the cluster.If any deviations are there in the yamls, it will automatically redeploy the same implementing the changes as per the git repo.







