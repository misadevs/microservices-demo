# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Terraform Backend Configuration for Google Cloud Storage
# 
# This configuration stores Terraform state remotely in GCS, which is required
# for CI/CD pipelines to maintain state between runs.
#
# SETUP INSTRUCTIONS:
# 1. Create the GCS bucket manually before running terraform init:
#    gsutil mb -p YOUR_PROJECT_ID -l us-central1 gs://YOUR_PROJECT_ID-terraform-state
#
# 2. Enable versioning for state recovery:
#    gsutil versioning set on gs://YOUR_PROJECT_ID-terraform-state
#
# 3. The bucket name and prefix are configured via backend-config in CI/CD:
#    terraform init \
#      -backend-config="bucket=YOUR_PROJECT_ID-terraform-state" \
#      -backend-config="prefix=online-boutique"

terraform {
  backend "gcs" {
    # These values are provided via -backend-config flags in CI/CD
    # bucket = "PROJECT_ID-terraform-state"
    # prefix = "online-boutique"
  }
}
