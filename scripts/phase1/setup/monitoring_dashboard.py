import streamlit as st
from kubernetes import client, config
import pandas as pd
from kubernetes.client.rest import ApiException
import urllib3

# Load Kubernetes configuration
try:
    config.load_kube_config()
except Exception as e:
    st.error(f"Error loading Kubernetes configuration: {e}")
    st.stop()

# Create Kubernetes API client
v1 = client.CoreV1Api()
apps_v1 = client.AppsV1Api()

st.title("Kubernetes Cluster Monitoring Dashboard")

# Fetch and display node information
st.header("Nodes")
try:
    nodes = v1.list_node()
    node_data = []
    for node in nodes.items:
        node_info = {
            "Name": node.metadata.name,
            "Status": node.status.conditions[-1].type,
            "CPU Capacity": node.status.capacity["cpu"],
            "Memory Capacity": node.status.capacity["memory"],
        }
        node_data.append(node_info)
    node_df = pd.DataFrame(node_data)
    st.dataframe(node_df)
except ApiException as e:
    st.error(f"Error fetching nodes: {e}")
except urllib3.exceptions.MaxRetryError as e:
    st.error(f"Max retries exceeded when trying to connect to the Kubernetes API server: {e}")

# Fetch and display pod information
st.header("Pods")
try:
    pods = v1.list_pod_for_all_namespaces()
    pod_data = []
    for pod in pods.items:
        pod_info = {
            "Name": pod.metadata.name,
            "Namespace": pod.metadata.namespace,
            "Node": pod.spec.node_name,
            "Status": pod.status.phase,
        }
        pod_data.append(pod_info)
    pod_df = pd.DataFrame(pod_data)
    st.dataframe(pod_df)
except ApiException as e:
    st.error(f"Error fetching pods: {e}")
except urllib3.exceptions.MaxRetryError as e:
    st.error(f"Max retries exceeded when trying to connect to the Kubernetes API server: {e}")

# Fetch and display service information
st.header("Services")
try:
    services = v1.list_service_for_all_namespaces()
    service_data = []
    for service in services.items:
        ports = ", ".join([f"{port.port}/{port.protocol}" for port in service.spec.ports])
        service_info = {
            "Name": service.metadata.name,
            "Namespace": service.metadata.namespace,
            "Type": service.spec.type,
            "Cluster IP": service.spec.cluster_ip,
            "External IP": service.spec.external_i_ps,
            "Ports": ports,
        }
        service_data.append(service_info)
    service_df = pd.DataFrame(service_data)
    st.dataframe(service_df)
except ApiException as e:
    st.error(f"Error fetching services: {e}")
except urllib3.exceptions.MaxRetryError as e:
    st.error(f"Max retries exceeded when trying to connect to the Kubernetes API server: {e}")

# Fetch and display deployment information
# st.header("Deployments")
# try:
#     deployments = apps_v1.list_deployment_for_all_namespaces()
#     deployment_data = []
#     for deployment in deployments.items:
#         deployment_info = {
#             "Name": deployment.metadata.name,
#             "Namespace": deployment.metadata.namespace,
#             "Replicas": deployment.spec.replicas,
#             "Available Replicas": deployment.status.available_replicas,
#             "Unavailable Replicas": deployment.status.unavailable_replicas,
#         }
#         deployment_data.append(deployment_info)
#     deployment_df = pd.DataFrame(deployment_data)
#     st.dataframe(deployment_df)
# except ApiException as e:
#     st.error(f"Error fetching deployments: {e}")
# except urllib3.exceptions.MaxRetryError as e:
#     st.error(f"Max retries exceeded when trying to connect to the Kubernetes API server: {e}")

# # Fetch and display resource usage information
# st.header("Resource Usage")
# try:
#     metrics_v1 = client.CustomObjectsApi()
#     resource_usage = metrics_v1.list_cluster_custom_object(
#         group="metrics.k8s.io", version="v1beta1", plural="nodes"
#     )
#     resource_data = []
#     for usage in resource_usage["items"]:
#         usage_info = {
#             "Name": usage["metadata"]["name"],
#             "CPU Usage": usage["usage"]["cpu"],
#             "Memory Usage": usage["usage"]["memory"],
#         }
#         resource_data.append(usage_info)
#     resource_df = pd.DataFrame(resource_data)
#     st.dataframe(resource_df)
# except ApiException as e:
#     if e.status == 404:
#         st.error("Metrics server not found. Ensure that the Kubernetes Metrics Server is installed and configured correctly.")
#         st.info("You can install the Metrics Server using the following command:")
#         st.code("kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml")
#     else:
#         st.error(f"Error fetching resource usage: {e}")
# except urllib3.exceptions.MaxRetryError as e:
#     st.error(f"Max retries exceeded when trying to connect to the Kubernetes API server: {e}")
