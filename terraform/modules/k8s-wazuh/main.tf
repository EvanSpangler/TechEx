# K8s Wazuh Agent Module - Deploys Wazuh agent as DaemonSet for container monitoring

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.0"
    }
  }
}

locals {
  cluster_name = var.wazuh_cluster_name != "" ? var.wazuh_cluster_name : "${var.environment}-eks"
}

# Namespace for Wazuh
resource "kubernetes_namespace" "wazuh" {
  metadata {
    name = var.namespace
    labels = {
      name        = var.namespace
      environment = var.environment
      app         = "wazuh-agent"
    }
  }
}

# ServiceAccount for Wazuh agent
resource "kubernetes_service_account" "wazuh_agent" {
  metadata {
    name      = "wazuh-agent"
    namespace = kubernetes_namespace.wazuh.metadata[0].name
    labels = {
      app = "wazuh-agent"
    }
  }
}

# ClusterRole for Wazuh agent to access Kubernetes API
resource "kubernetes_cluster_role" "wazuh_agent" {
  metadata {
    name = "wazuh-agent"
    labels = {
      app = "wazuh-agent"
    }
  }

  # Permissions for Kubernetes API monitoring
  rule {
    api_groups = [""]
    resources  = ["pods", "nodes", "namespaces", "events", "services", "configmaps"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["deployments", "daemonsets", "replicasets", "statefulsets"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["batch"]
    resources  = ["jobs", "cronjobs"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["networkpolicies", "ingresses"]
    verbs      = ["get", "list", "watch"]
  }

  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["clusterroles", "clusterrolebindings", "roles", "rolebindings"]
    verbs      = ["get", "list", "watch"]
  }
}

# ClusterRoleBinding for Wazuh agent
resource "kubernetes_cluster_role_binding" "wazuh_agent" {
  metadata {
    name = "wazuh-agent"
    labels = {
      app = "wazuh-agent"
    }
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role.wazuh_agent.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.wazuh_agent.metadata[0].name
    namespace = kubernetes_namespace.wazuh.metadata[0].name
  }
}

# ConfigMap for Wazuh agent configuration
resource "kubernetes_config_map" "wazuh_agent" {
  metadata {
    name      = "wazuh-agent-config"
    namespace = kubernetes_namespace.wazuh.metadata[0].name
    labels = {
      app = "wazuh-agent"
    }
  }

  data = {
    "ossec.conf" = <<-EOF
      <ossec_config>
        <client>
          <server>
            <address>${var.wazuh_manager_ip}</address>
            <port>1514</port>
            <protocol>tcp</protocol>
          </server>
          <config-profile>ubuntu, ubuntu22, ubuntu22.04</config-profile>
          <notify_time>10</notify_time>
          <time-reconnect>60</time-reconnect>
          <auto_restart>yes</auto_restart>
        </client>

        <client_buffer>
          <disabled>no</disabled>
          <queue_size>5000</queue_size>
          <events_per_second>500</events_per_second>
        </client_buffer>

        <!-- File integrity monitoring -->
        <syscheck>
          <disabled>no</disabled>
          <frequency>43200</frequency>
          <scan_on_start>yes</scan_on_start>
          <directories check_all="yes" realtime="yes">/etc,/usr/bin,/usr/sbin,/bin,/sbin</directories>
          <directories check_all="yes">/var/log</directories>
          <ignore>/etc/mtab</ignore>
          <ignore>/etc/hosts.deny</ignore>
          <ignore>/etc/mail/statistics</ignore>
          <ignore>/etc/random-seed</ignore>
          <ignore>/etc/adjtime</ignore>
          <ignore>/etc/prelink.cache</ignore>
        </syscheck>

        <!-- Log monitoring -->
        <localfile>
          <log_format>syslog</log_format>
          <location>/var/log/syslog</location>
        </localfile>

        <localfile>
          <log_format>syslog</log_format>
          <location>/var/log/auth.log</location>
        </localfile>

        <!-- Container runtime logs -->
        <localfile>
          <log_format>json</log_format>
          <location>/var/log/containers/*.log</location>
        </localfile>

        <!-- Rootcheck -->
        <rootcheck>
          <disabled>no</disabled>
          <frequency>43200</frequency>
          <check_files>yes</check_files>
          <check_trojans>yes</check_trojans>
          <check_dev>yes</check_dev>
          <check_sys>yes</check_sys>
          <check_pids>yes</check_pids>
          <check_ports>yes</check_ports>
          <check_if>yes</check_if>
        </rootcheck>

        <!-- Security Configuration Assessment -->
        <sca>
          <enabled>yes</enabled>
          <scan_on_start>yes</scan_on_start>
          <interval>12h</interval>
          <skip_nfs>yes</skip_nfs>
        </sca>

        <!-- Vulnerability Detection -->
        <vulnerability-detection>
          <enabled>yes</enabled>
          <index-status>yes</index-status>
          <feed-update-interval>60m</feed-update-interval>
        </vulnerability-detection>

        <!-- Syscollector for inventory -->
        <wodle name="syscollector">
          <disabled>no</disabled>
          <interval>1h</interval>
          <scan_on_start>yes</scan_on_start>
          <hardware>yes</hardware>
          <os>yes</os>
          <network>yes</network>
          <packages>yes</packages>
          <ports all="yes">yes</ports>
          <processes>yes</processes>
          <hotfixes>yes</hotfixes>
        </wodle>

        <!-- Docker monitoring -->
        <wodle name="docker-listener">
          <disabled>no</disabled>
        </wodle>

        <labels>
          <label key="cluster">${local.cluster_name}</label>
          <label key="node_type">kubernetes</label>
        </labels>
      </ossec_config>
    EOF
  }
}

# DaemonSet for Wazuh agent
resource "kubernetes_daemonset" "wazuh_agent" {
  metadata {
    name      = "wazuh-agent"
    namespace = kubernetes_namespace.wazuh.metadata[0].name
    labels = {
      app = "wazuh-agent"
    }
  }

  spec {
    selector {
      match_labels = {
        app = "wazuh-agent"
      }
    }

    template {
      metadata {
        labels = {
          app = "wazuh-agent"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.wazuh_agent.metadata[0].name
        host_network         = true
        host_pid             = true

        # Tolerate all taints to run on all nodes including masters
        toleration {
          operator = "Exists"
        }

        init_container {
          name  = "wazuh-agent-init"
          image = "wazuh/wazuh-agent:${var.wazuh_agent_version}"

          command = ["/bin/bash", "-c"]
          args = [
            <<-EOF
              cp /var/ossec/etc/ossec.conf /var/ossec/etc/ossec.conf.backup 2>/dev/null || true
              cp /config/ossec.conf /var/ossec/etc/ossec.conf
              chown root:wazuh /var/ossec/etc/ossec.conf
              chmod 640 /var/ossec/etc/ossec.conf
            EOF
          ]

          volume_mount {
            name       = "config"
            mount_path = "/config"
          }

          volume_mount {
            name       = "wazuh-agent-etc"
            mount_path = "/var/ossec/etc"
          }

          security_context {
            run_as_user = 0
          }
        }

        container {
          name  = "wazuh-agent"
          image = "wazuh/wazuh-agent:${var.wazuh_agent_version}"

          env {
            name  = "WAZUH_MANAGER"
            value = var.wazuh_manager_ip
          }

          env {
            name = "WAZUH_AGENT_NAME"
            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }

          env {
            name  = "WAZUH_AGENT_GROUP"
            value = "kubernetes"
          }

          security_context {
            privileged = true
            capabilities {
              add = ["SYS_PTRACE", "SYS_ADMIN", "NET_ADMIN", "AUDIT_CONTROL", "AUDIT_READ"]
            }
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
          }

          volume_mount {
            name       = "wazuh-agent-etc"
            mount_path = "/var/ossec/etc"
          }

          volume_mount {
            name       = "wazuh-agent-var"
            mount_path = "/var/ossec/var"
          }

          volume_mount {
            name       = "wazuh-agent-logs"
            mount_path = "/var/ossec/logs"
          }

          volume_mount {
            name       = "var-log"
            mount_path = "/var/log"
            read_only  = true
          }

          volume_mount {
            name       = "var-log-containers"
            mount_path = "/var/log/containers"
            read_only  = true
          }

          volume_mount {
            name       = "var-log-pods"
            mount_path = "/var/log/pods"
            read_only  = true
          }

          volume_mount {
            name       = "docker-sock"
            mount_path = "/var/run/docker.sock"
            read_only  = true
          }

          volume_mount {
            name       = "containerd-sock"
            mount_path = "/run/containerd/containerd.sock"
            read_only  = true
          }

          volume_mount {
            name       = "etc-os-release"
            mount_path = "/etc/os-release"
            read_only  = true
          }

          volume_mount {
            name       = "host-etc"
            mount_path = "/host/etc"
            read_only  = true
          }

          liveness_probe {
            exec {
              command = ["/var/ossec/bin/wazuh-control", "status"]
            }
            initial_delay_seconds = 60
            period_seconds        = 30
            timeout_seconds       = 10
            failure_threshold     = 3
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.wazuh_agent.metadata[0].name
          }
        }

        volume {
          name = "wazuh-agent-etc"
          empty_dir {}
        }

        volume {
          name = "wazuh-agent-var"
          empty_dir {}
        }

        volume {
          name = "wazuh-agent-logs"
          empty_dir {}
        }

        volume {
          name = "var-log"
          host_path {
            path = "/var/log"
            type = "Directory"
          }
        }

        volume {
          name = "var-log-containers"
          host_path {
            path = "/var/log/containers"
            type = "DirectoryOrCreate"
          }
        }

        volume {
          name = "var-log-pods"
          host_path {
            path = "/var/log/pods"
            type = "DirectoryOrCreate"
          }
        }

        volume {
          name = "docker-sock"
          host_path {
            path = "/var/run/docker.sock"
            type = "" # Empty type allows missing socket (EKS nodes may not have Docker)
          }
        }

        volume {
          name = "containerd-sock"
          host_path {
            path = "/run/containerd/containerd.sock"
            type = "" # Empty type allows missing socket
          }
        }

        volume {
          name = "etc-os-release"
          host_path {
            path = "/etc/os-release"
            type = "File"
          }
        }

        volume {
          name = "host-etc"
          host_path {
            path = "/etc"
            type = "Directory"
          }
        }
      }
    }
  }
}
