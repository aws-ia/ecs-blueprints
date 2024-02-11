
# import required torch and ray libraries
import torch
from torchvision.models import resnet18
from torchvision.datasets import FashionMNIST
from torchvision.transforms import ToTensor, Normalize, Compose
from torch.utils.data import DataLoader
from torch.optim import Adam
from torch.nn import CrossEntropyLoss
from ray.train.torch import TorchTrainer
from ray.train import ScalingConfig, RunConfig
from filelock import FileLock
import ray
import time
import argparse

# Get arguments

parser = argparse.ArgumentParser()
parser.add_argument("bucket_name", help="Bucket to publish results.", type=str)
args = parser.parse_args()


# Connect to the Ray cluster
ray.init()

# Download the data in the shared storage
transform = Compose([ToTensor(), Normalize((0.5,), (0.5,))])
train_data = FashionMNIST(root='./data',
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
    with FileLock(os.path.expanduser("./data.lock")):
        train_data = FashionMNIST(root='./data', train=True, download=True, transform=transform)
        # Download test data from open datasets
        test_data = FashionMNIST(root="./data",train=False,download=True,transform=transform)
    batch_size=128
    train_loader = DataLoader(train_data, batch_size=batch_size, shuffle=True)
    test_loader = DataLoader(test_data, batch_size=batch_size)
    # Prepare dataloader for distributed training
    train_loader = ray.train.torch.prepare_data_loader(train_loader)
    test_loader = ray.train.torch.prepare_data_loader(test_loader)
    # Define training loop
    for epoch in range(10):
        start = time.time()
        model.train()
        for images, labels in train_loader:
            outputs = model(images)
            loss = criterion(outputs, labels)
            optimizer.zero_grad()
            loss.backward()
            optimizer.step()
        print(f"[Epoch {epoch} | GPU{torch.cuda.current_device()}: Process rank {torch.distributed.get_rank()} | Batchsize: {128} | Steps: {len(train_loader)} | Total epoch time: {time.time()-start}]")
        model.eval()
        test_loss, num_correct, num_total = 0, 0, 0

        # Calculate loss and accuaricy in the 10th epoch
        # you might want to do this in each epoch to detect overfitting as early as possible
        if epoch == 9:
            with torch.no_grad():
                for images, labels in test_loader:
                    prediction = model(images)
                    loss = criterion(prediction, labels)
                    test_loss += loss.item()
                    num_total += labels.shape[0]
                    num_correct += (prediction.argmax(1) == labels).sum().item()

                test_loss /= len(test_loader)
                accuracy = num_correct / num_total
            # Report metrics and checkpoint to Ray.
            ray.train.report(metrics={"loss": test_loss, "accuracy": accuracy})

# The scaling config defines how many worker processes to use for the training. Usually equals to the number of GPUs
scaling_config = ScalingConfig(num_workers=2, use_gpu=True)

# Create the trainer instance
trainer = TorchTrainer(train_func,
                       scaling_config=scaling_config,
                       run_config=RunConfig(
                           storage_path=f"s3://{args.bucket_name}/",
                            name="ecs_dt_results")
                    )

# Run the training
result = trainer.fit()

# Print the results of the training
print(result)
