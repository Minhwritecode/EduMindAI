# scripts/train_vark_model.py
"""Train a VARK learning style classifier using a tiny transformer model.

Usage:
  python scripts/train_vark_model.py [--epochs N] [--batch_size B]

The script reads `dataset.csv` at project root, fine‑tunes a tiny DistilRoBERTa model,
evaluates on a validation split, and saves the model, tokenizer and label encoder.
"""
import argparse
import os
import joblib
import pandas as pd
import torch
from torch.utils.data import DataLoader, Dataset
from transformers import AutoTokenizer, AutoModelForSequenceClassification, Trainer, TrainingArguments
from sklearn.preprocessing import LabelEncoder
from sklearn.metrics import accuracy_score, classification_report

class VarkDataset(Dataset):
    def __init__(self, texts, labels, tokenizer, max_len=128):
        self.texts = texts
        self.labels = labels
        self.tokenizer = tokenizer
        self.max_len = max_len

    def __len__(self):
        return len(self.texts)

    def __getitem__(self, idx):
        encoding = self.tokenizer(
            self.texts[idx],
            truncation=True,
            padding='max_length',
            max_length=self.max_len,
            return_tensors='pt',
        )
        item = {k: v.squeeze(0) for k, v in encoding.items()}
        item['labels'] = torch.tensor(self.labels[idx], dtype=torch.long)
        return item

def compute_metrics(eval_pred):
    logits, labels = eval_pred
    preds = torch.argmax(torch.tensor(logits), dim=-1).numpy()
    acc = accuracy_score(labels, preds)
    return {"accuracy": acc}

def main():
    parser = argparse.ArgumentParser(description="Train VARK classifier with tiny transformer")
    parser.add_argument("--epochs", type=int, default=2, help="Number of training epochs")
    parser.add_argument("--batch_size", type=int, default=8, help="Batch size for training")
    args = parser.parse_args()

    data_path = os.path.join(os.path.dirname(__file__), "..", "dataset.csv")
    df = pd.read_csv(data_path)
    texts = df["Sentence"].astype(str).tolist()
    labels = df["Type"].astype(str).tolist()

    le = LabelEncoder()
    y = le.fit_transform(labels)
    # Simple train/val split
    train_ratio = 0.8
    split_idx = int(len(texts) * train_ratio)
    train_texts, val_texts = texts[:split_idx], texts[split_idx:]
    train_labels, val_labels = y[:split_idx], y[split_idx:]

    model_name = "sshleifer/tiny-distilroberta-base"
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    model = AutoModelForSequenceClassification.from_pretrained(
        model_name, num_labels=len(le.classes_)
    )

    train_dataset = VarkDataset(train_texts, train_labels, tokenizer)
    val_dataset = VarkDataset(val_texts, val_labels, tokenizer)

    training_args = TrainingArguments(
        output_dir="./model_output",
        num_train_epochs=args.epochs,
        per_device_train_batch_size=args.batch_size,
        per_device_eval_batch_size=args.batch_size,
        evaluation_strategy="epoch",
        save_strategy="no",
        logging_strategy="steps",
        logging_steps=10,
        load_best_model_at_end=False,
        report_to=[],
        fp16=False,
    )

    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=train_dataset,
        eval_dataset=val_dataset,
        compute_metrics=compute_metrics,
    )

    trainer.train()
    # Evaluate on validation set
    metrics = trainer.evaluate()
    print(f"Validation Accuracy: {metrics['eval_accuracy']:.4f}")
    # Save artifacts to project root
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    torch.save(model.state_dict(), os.path.join(root_dir, "learning_style_model.pt"))
    tokenizer.save_pretrained(root_dir)
    joblib.dump(le, os.path.join(root_dir, "label_encoder.pkl"))
    print("Model, tokenizer and label encoder saved to project root.")

if __name__ == "__main__":
    main()
