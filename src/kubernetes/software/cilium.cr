require "../../configuration/loader"
require "../../configuration/main"
require "../../util"
require "../../util/shell"

class Kubernetes::Software::Cilium
  include Util
  include Util::Shell

  getter configuration : Configuration::Loader
  getter settings : Configuration::Main { configuration.settings }

  def initialize(@configuration, @settings)
  end

  def install
    log_line "Installing Cilium..."

    command = <<-BASH
    helm repo add cilium https://helm.cilium.io/

    helm upgrade --install \
    --version #{settings.networking.cni.cilium.chart_version} \
    --namespace kube-system \
    --set encryption.enabled=true \
    --set encryption.type=wireguard \
    --set encryption.nodeEncryption=true \
    --set routingMode=tunnel \
    --set tunnelProtocol=vxlan \
    --set kubeProxyReplacement=true \
    --set hubble.enabled=true \
    --set hubble.metrics.enabled="{dns,drop,tcp,flow,port-distribution,icmp,http}" \
    --set hubble.relay.enabled=true \
    --set hubble.ui.enabled=true \
    --set k8sServiceHost=127.0.0.1 \
    --set k8sServicePort=6444 \
    --set operator.replicas=1 \
    cilium cilium/cilium

    echo "Waiting for Cilium to be ready..."
    kubectl -n kube-system rollout status ds cilium

    echo "Rescheduling Cilium-unmmanged pods..."
    kubectl get pods --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,HOSTNETWORK:.spec.hostNetwork --no-headers=true | grep '<none>' | awk '{print "-n "$1" "$2}' | xargs -r kubectl delete pod
    BASH

    run_shell_command(command, configuration.kubeconfig_path, settings.hetzner_token)

    log_line "...Cilium installed"
  end

  private def default_log_prefix
    "CNI"
  end
end
