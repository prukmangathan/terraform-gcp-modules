provider "google" {
  credentials = file("model-hexagon-351804-6b3b6f158f1e.json")
  region      = "us-central1"
  project     = "model-hexagon-351804"
}

provider "google-beta" {
  credentials = file("model-hexagon-351804-6b3b6f158f1e.json")
  project     = "model-hexagon-351804"
  region      = "us-central1"
}

resource "random_string" "suffix" {
  length  = 4
  special = "false"
  upper   = "false"
}

module "cloud-nat" {
  source        = "./modules/cloud-nat"
  create_router = true
  router        = "test-router"
  project_id    = "model-hexagon-351804"
  region        = "us-central1"
  name          = "my-cloud-nat"
  network       = google_compute_network.main.id
}

resource "google_compute_network" "main" {
  project                 = "model-hexagon-351804"
  name                    = "cft-vm-test-${random_string.suffix.result}"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "main" {
  project       = "model-hexagon-351804"
  region        = "us-central1"
  name          = "cft-vm-test-${random_string.suffix.result}"
  ip_cidr_range = "10.128.0.0/20"
  network       = google_compute_network.main.self_link
}

/** Instance Template **/

module "instance_template" {
  source     = "./modules/instance-template"
  project_id = "model-hexagon-351804"
  subnetwork = google_compute_subnetwork.main.name
  service_account = {
    email  = "iaac-sa@model-hexagon-351804.iam.gserviceaccount.com",
    scopes = ["cloud-platform"]
  }
}

/** Instance Group within autoscale and health check **/

module "mig" {
  source              = "./modules/mig"
  project_id          = "model-hexagon-351804"
  instance_template   = module.instance_template.self_link
  region              = "us-central1"
  autoscaling_enabled = true
  min_replicas        = 2
  autoscaler_name     = "mig-as"
  hostname            = "mig-as"

  autoscaling_cpu = [
    {
      target = 0.4
    },
  ]

  health_check_name = "mig-https-hc"
  health_check = {
    type                = "http"
    initial_delay_sec   = 120
    check_interval_sec  = 5
    healthy_threshold   = 2
    timeout_sec         = 5
    unhealthy_threshold = 2
    response            = ""
    proxy_header        = "NONE"
    port                = 80
    request             = ""
    request_path        = "/"
    host                = "localhost"
  }
}