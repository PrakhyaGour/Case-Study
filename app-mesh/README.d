For the canary deployment will be using app-mesh of AWS in our cae-study

What is App-mesh?

App Mesh makes it easy to run microservices by providing consistent visibility and network traffic controls for every microservice in an application. App Mesh separates the logic needed for monitoring and controlling communications into a proxy that runs next to every microservice. App Mesh removes the need to coordinate across teams or update application code to change how monitoring data is collected or traffic is routed. This allows you to quickly pinpoint the exact location of errors and automatically re-route network traffic when there are failures or when code changes need to be deployed.

You can use App Mesh with AWS Fargate, Amazon Elastic Container Service (ECS), Amazon Elastic Container Service for Kubernetes (EKS), and Kubernetes on EC2 to better run containerized microservices at scale. App Mesh uses Envoy, an open source proxy, making it compatible with a wide range of AWS partner and open source tools for monitoring microservices

App-mesh setup:
Steps:
-Add k8s-appmesh-worker-policy.json to the k8s worker nodes which gives it access to AWS app-mesh service.
 aws iam put-role-policy --role-name $ROLE_NAME --policy-name AM-Policy-For-Worker --policy-document file://k8s-appmesh-worker-policy.json
 Here ROLE_NAME would be your worker node role.
 You can check the access by deploying awscli.yaml and running "kubectl logs jobs/awscli"

-As we have our initial application running in cas-study namespace.We I have given the app name as hello-v1 which will make more sense when we setup the canary deployment.

-You can check the application by putting the elb name which you get when you run "kubectl get svc" in the brower if it is working as per your expectations.

{{Injectors/Sidecars}}
What are sidecars?
Sidecar is a microservices design pattern where a companion service runs next to your primary microservice, augmenting its abilities or intercepting resources it is utilizing. In the case of App Mesh, a sidecar container, Envoy, is used as a proxy for all ingress and egress traffic to the primary microservice. Using this sidecar pattern with Envoy we create the backbone of the service mesh, without impacting our applications.

Injectors
Kubernetes can hook into actions on Kubernetes objects before the system executes them. This allows two main functions: validation and mutation. Validation works as a gatekeeper for any operation on any resource in Kubernetes, allowing you to block actions before they execute. Mutation allows you to change the specification of a Kubernetes resource before initiation. Mutation provides the functionality for App Mesh injector.

-We can implement the App Mesh Injector Controller, which watches for new pods to be created, and automatically adds the sidecar data to the pods as they are deployed.-Go to the injector folder and run ./create.sh
 It will create mulitple dependency which an injector will be requiring.(ssl/ca-bundles)
-Next, we’ll verify the Injector Controller is running:
 kubectl get pods -nappmesh-inject
-By default, the injector won’t act on any pods — we’ll need to give it criteria on what its auto-inject targets should be.
 For the purpose of this tutorial, we’ll make it inject the App Mesh sidecar into any new pods created in the prod namespace. To do that, we’ll label our prod namespace with appmesh.k8s.aws/sidecarInjectorWebhook=enabled.
 label the namespace:
 kubectl label namespace prod appmesh.k8s.aws/sidecarInjectorWebhook=enabled
 
 {{CRD}}
-To setup the components of app-mesh,add Custom Resource Definitions (CRDs), and the App Mesh controller logic that syncs our kubernetes cluster’s CRD state with the AWS cloud-side App Mesh control plane.
 cd CRD/
 kubectl apply -f 3_add_crds/mesh-definition.yaml
 kubectl apply -f 3_add_crds/virtual-node-definition.yaml
 kubectl apply -f 3_add_crds/virtual-service-definition.yaml
 kubectl apply -f 3_add_crds/controller-deployment.yaml
 kubectl get pods -nappmesh-system
 These CRDS are using when we create CRDs and canary implementation in k8s.

{{MESH}}
-Creating a mesh
 cd mesh_component
 kubectl create -f 4_create_initial_mesh_components/mesh.yaml
 kubectl get meshes -nprod
 aws appmesh describe-mesh --mesh-name hello
 
{{Virtual service and virtual node}}
-Vitual Nodes and Virtual Services
 With the foundational mesh component created, we’ll continue onward to define the App Mesh Virtual Node and Virtual Service components.
 All services (physical or virtual) that will interact in any way with each other in App Mesh must first be defined as Virtual Node objects. Abstracting out services as Virtual Nodes helps App Mesh build rulesets around inter-service communication. In addition, as we define Virtual Service objects, Virtual Nodes are referenced as the ingress and target endpoints for those Virtual Services. Because of this, it makes sense to define the Virtual Nodes first.

-Creating a Virtual node which points to virtual services.
 kubectl create -f 4_create_initial_mesh_components/nodes_representing_virtual_services.yaml
-Creating a Virtual node which points to physical service(our hello app).
 kubectl create -nprod -f 4_create_initial_mesh_components/nodes_representing_physical_services.yaml
 verify:
 kubectl get virtualnodes -nprod
-The next step is to create the two App Mesh Virtual Services that will intercept and route requests made to hello app.
 kubectl apply -nprod -f 4_create_initial_mesh_components/virtual-services.yaml
-With these Virtual Services defined, to access them by name, clients (in our case, the dj container) will first perform a DNS lookup request to hello.case-study.svc.cluster.local, before making the request.
 Our other physical service (hello) are defined as physical kubernetes services, and therefore have discoverable names and IPs. However, these Virtual Services don’t (yet).
-Creating a placeholder for the virtual service
 kubectl create -nprod -f 4_create_initial_mesh_components/hello_placeholder_services.yaml
 Verify:
 kubectl get svc -nprod (It should give two service(virtual and physical)
  ![alt test]  (IMG_20200210_135352.jpg)                     
-Bootstrap injector
 Right now, if we describe any of the pods running in the prod namespace, we’ll notice that they are running with just one container, the same one we initially deployed it with:
 Next, run the following commands to add a date label to each pod
 kubectl patch deployment hello-v1 -n case-study -p "{\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"date\":\"`date +'%s'`\"}}}}}"
- kubectl get pods -nprod
  Now this command will show you 2 containers running inside one hello pod.
-Now you can verify if the application is accesible from the virtual service.
 
Testing canary
A canary release is a method of slowly exposing a new version of software. The theory behind it is that by serving the new version of the software initially to say, 5% of requests, if there is a problem, the problem only impacts a very small percentage of users before its discovered and rolled back.
- Deploy the version 2 of hello app and updated service 
  kubectl apply -f canary/hello_v2.yaml
  kubectl apply -f canary/hello_service_update.yaml
If you see in the hello_service_update.yaml file, we have only routed 10% of the traffic to the new version.

Will monitor the new version using multple monitoring tool like prometheus, datadog and etc and decide whether to continue with the new version or role.
We can do it manually while changing the weighted percentage in the update service or we can use flagger for the same.

What is flagger?
Flagger takes a Kubernetes deployment and optionally a horizontal pod autoscaler (HPA), then creates a series of objects (Kubernetes deployments, ClusterIP services, App Mesh virtual nodes and services). These objects expose the application on the mesh and drive the canary analysis and promotion. The only App Mesh object you need to create by yourself is the mesh resource. 

