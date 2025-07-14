# Deployment Guide: Oracle Cloud Free Tier

This guide explains how to deploy the LetAgents_DYOR backend on an **Oracle Cloud Infrastructure (OCI) Always Free** VM.

## 1. Create an Always Free VM
1. Sign in to your Oracle Cloud account (a credit card is required for signup, but staying within the free tier incurs no charges).
2. Navigate to **Compute \> Instances** and create a new instance.
3. Choose an **Always Free eligible shape** such as `VM.Standard.E2.1.Micro` (1 OCPU, 1GB RAM) and select **Ubuntu 22.04** as the OS image.
4. Finish the wizard and note the public IP address of your VM.

## 2. Open the Application Port
Oracle's default security list may block custom ports. To allow traffic on port **8000** (or another port you prefer):
1. Go to **Networking \> Virtual Cloud Networks** and open the VCN used by your VM.
2. Under **Security Lists**, edit (or create) an **Ingress Rule**:
   - **Source CIDR:** `0.0.0.0/0`
   - **IP Protocol:** TCP
   - **Destination Port Range:** `8000` (or `80` if you map the container to port 80)
3. Save the rule. This exposes the port publicly.
4. Ensure the VM's own firewall allows the traffic. Ubuntu's `ufw` is off by default, but you can explicitly allow the port:
   ```bash
   sudo ufw allow 8000/tcp
   ```
   or use `iptables` rules if you have a custom setup.

## 3. Deploy the Backend
There are two options for deployment on the VM.

### Option A: Using Docker (recommended)
1. Install Docker:
   ```bash
   sudo apt update && sudo apt install -y docker.io
   ```
2. Clone this repository on the VM and navigate to the project directory.
3. Build or pull the container image. If a prebuilt image is available on Docker Hub or the Oracle Container Registry, you can pull it. Otherwise build from the Dockerfile:
   ```bash
docker build -t letagents-backend .
   ```
4. Run the container, mapping the exposed port. The backend already binds to `0.0.0.0`, so it will be reachable externally:
   ```bash
docker run -d -p 80:8000 letagents-backend
   ```
   This maps port 8000 in the container to port 80 on the VM (you can also expose 8000 directly).

### Option B: Run Directly on the VM
1. Install Python and requirements:
   ```bash
   sudo apt update && sudo apt install -y python3 python3-pip
   pip3 install -r backend/requirements.txt
   ```
2. Set environment variables for API keys:
   ```bash
   export OPENAI_API_KEY=your-openai-key
   export FINNHUB_API_KEY=your-finnhub-key
   ```
3. Start the server:
   ```bash
   uvicorn backend.main:app --host 0.0.0.0 --port 8000
   ```
   This approach is useful for quick testing, though Docker provides consistency for production.

## 4. Oracle Free Tier Constraints
The free VM provides limited CPU and RAM. The backend also calls external APIs (OpenAI, Finnhub) which may incur costs depending on usage. Be mindful of resource usage and API call volume.

## 5. Scaling Considerations
As usage grows, you can move to a larger instance or deploy multiple containers behind a load balancer. For a multi-instance setup, consider replacing the default SQLite database with Oracle's free Autonomous Database. The separation of backend and Flutter front-end already allows horizontal scaling.

## 6. Test the Deployment
1. After starting the server or Docker container, visit:
   ```
   http://<your-vm-ip>:8000/
   ```
   You should see `{"message": "Backend up"}`.
2. Update the Flutter app's API base URL if needed and run it on your device. Log in and verify functionality.

---
Following these steps lets you run LetAgents_DYOR on OCI's Always Free resources with minimal cost.
