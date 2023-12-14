
# import required torch and ray libraries
import tempfile
import torch
from torchvision.models import resnet18
from torchvision.datasets import FashionMNIST
from torchvision.transforms import ToTensor, Normalize, Compose
from torch.utils.data import DataLoader
from torch.optim import Adam
from torch.nn import CrossEntropyLoss
from ray.train.torch import TorchTrainer
from ray.train import ScalingConfig, Checkpoint
import ray
from pprint import pprint
import time
from pprint import pprint

# Connect to the Ray cluster
ray.init()

# Download the data in the shared storage
transform = Compose([ToTensor(), Normalize((0.5,), (0.5,))])
train_data = FashionMNIST(root='/home/ray/ray_results/data',
                          train=True, download=True,
                          transform=transform)

# Define the training function that the distributed processes will run
def train_func(config):
    import os
    # The NVIDIA Collective Communications Library (NCCL) implements multi-GPU
    # and multi-node communication primitives optimized for NVIDIA GPUs.
    # Since containers can have multiple interfaces, we explicitly set which one
    # NCCL should use.
    os.environ['NCCL_SOCKET_IFNAME']='eth0'
    #os.environ['NCCL_DEBUG']='INFO' Uncomment this line if you want to debug NCCL
    # Set up the model
    model = resnet18(num_classes=10)
    model.conv1 = torch.nn.Conv2d(1, 64, kernel_size=(7, 7),
                                  stride=(2, 2),
                                  padding=(3, 3),
                                  bias=False)
    # Prepare model for distributed training
    model = ray.train.torch.prepare_model(model)
    # Setup loss and optimizer
    criterion = CrossEntropyLoss()
    optimizer = Adam(model.parameters(), lr=0.001)
    # Retrieve the data from the shared storage.
    transform = Compose([ToTensor(), Normalize((0.5,), (0.5,))])
    train_data = FashionMNIST(root='/home/ray/ray_results/data', train=True, download=False, transform=transform)
    train_loader = DataLoader(train_data, batch_size=128, shuffle=True)
    # Prepare dataloader for distributed training
    train_loader = ray.train.torch.prepare_data_loader(train_loader)
    # Define training loop
    for epoch in range(10):
        start = time.time()
        for images, labels in train_loader:
            outputs = model(images)
            loss = criterion(outputs, labels)
            optimizer.zero_grad()
            loss.backward()
            optimizer.step()
        print(f"[GPU{torch.cuda.current_device()}: Process rank {torch.distributed.get_rank()}] | [Epoch {epoch} | Batchsize: {128} | Steps: {len(train_loader)} | Total epoch time: {time.time()-start}]")
        # Only save checkpoint after the last epoch
        if epoch == 9:
            checkpoint_dir = tempfile.gettempdir()  
            checkpoint_path = checkpoint_dir + "/model.checkpoint"
            torch.save(model.state_dict(), checkpoint_path)
            # Report metrics and checkpoint to Ray.
            ray.train.report({"loss": loss.item()},checkpoint=Checkpoint.from_directory(checkpoint_dir))

# The scaling config defines how many workers
# In this case is equal to the total GPU count  
scaling_config = ScalingConfig(num_workers=8, use_gpu=True)

# Create the trainer instance
trainer = TorchTrainer(train_func,
                       scaling_config=scaling_config)

# Run the training
result = trainer.fit()

# Print the results of the training
print(result)