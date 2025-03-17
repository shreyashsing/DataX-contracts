import pandas as pd
import hashlib
import json
import spacy
import re
from sklearn.ensemble import IsolationForest
from sklearn.feature_extraction.text import TfidfVectorizer
from web3 import Web3
import os

# Load NLP model for PII detection
nlp = spacy.load("en_core_web_sm")

# Web3 setup (connect to Hardhat node)
w3 = Web3(Web3.HTTPProvider("http://127.0.0.1:8545"))
owner_address = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"  # Hardhat account 0
private_key = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"  # Hardhat private key
ai_verification_address = "0xYourAIVerificationAddress"  # From deployment
with open("AIVerification.json") as f:
    abi = json.load(f)["abi"]
contract = w3.eth.contract(address=ai_verification_address, abi=abi)

class AIVerificationModel:
    def __init__(self):
        self.existing_hashes = set()  # Mock database of dataset hashes

    def preprocess_input(self, file_path):
        """Handle CSV, JSON, or Parquet input."""
        if file_path.endswith(".csv"):
            df = pd.read_csv(file_path)
        elif file_path.endswith(".json"):
            df = pd.read_json(file_path)
        elif file_path.endswith(".parquet"):
            df = pd.read_parquet(file_path)
        else:
            raise ValueError("Unsupported file format")
        
        dataset_hash = hashlib.sha256(pd.util.hash_pandas_object(df).tobytes()).hexdigest()
        metadata = {"rows": len(df), "columns": df.columns.tolist(), "size": os.path.getsize(file_path)}
        return df, dataset_hash, metadata

    def data_quality_check(self, df):
        """Check missing values, types, and anomalies."""
        missing_values = df.isnull().sum().sum()
        incorrect_types = sum(1 for col in df if df[col].dtype == object and col not in ["category"])
        return {"missingValues": int(missing_values), "incorrectTypes": incorrect_types}

    def pii_detection(self, df):
        """Detect PII using NLP and regex."""
        pii_count = 0
        for col in df:
            for val in df[col].astype(str):
                doc = nlp(val)
                if any(ent.label_ in ["PERSON", "GPE", "ORG"] for ent in doc.ents):
                    pii_count += 1
                if re.search(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b", val):  # Email
                    pii_count += 1
        return pii_count > 0

    def relevance_check(self, df, claimed_category):
        """Classify dataset relevance (mock)."""
        columns = df.columns
        finance_keywords = ["price", "stock", "date"]
        health_keywords = ["patient", "diagnosis", "treatment"]
        if claimed_category == "Finance" and any(kw in col.lower() for kw in finance_keywords for col in columns):
            return "Finance"
        elif claimed_category == "Health" and any(kw in col.lower() for kw in health_keywords for col in columns):
            return "Health"
        return "Unknown"

    def authenticity_check(self, dataset_hash):
        """Check for duplicates and anomalies."""
        is_duplicate = dataset_hash in self.existing_hashes
        self.existing_hashes.add(dataset_hash)
        return not is_duplicate

    def bias_detection(self, df):
        """Check for demographic imbalance (mock)."""
        if "gender" in df.columns:
            gender_counts = df["gender"].value_counts(normalize=True)
            if max(gender_counts) > 0.7:  # More than 70% one gender
                return "Imbalanced"
        return "Balanced"

    def generate_report(self, file_path, claimed_category="Finance"):
        """Run all checks and return JSON report."""
        df, dataset_hash, metadata = self.preprocess_input(file_path)
        quality = self.data_quality_check(df)
        pii_detected = self.pii_detection(df)
        relevance = self.relevance_check(df, claimed_category)
        is_authentic = self.authenticity_check(dataset_hash)
        bias = self.bias_detection(df)

        is_verified = (quality["missingValues"] < 10 and not pii_detected and 
                       relevance == claimed_category and is_authentic and bias == "Balanced")
        quality_score = min(100, 100 - quality["missingValues"] - (10 if pii_detected else 0) - 
                           (20 if relevance != claimed_category else 0) - (20 if not is_authentic else 0) - 
                           (10 if bias != "Balanced" else 0))
        verification_hash = hashlib.sha256(json.dumps({"quality": quality, "pii": pii_detected}).encode()).hexdigest()

        report = {
            "datasetHash": "0x" + dataset_hash,
            "verificationHash": "0x" + verification_hash,
            "isVerified": is_verified,
            "qualityScore": quality_score,
            "analysisReport": "ipfs://mock-report",  # Replace with real IPFS upload
            "details": {
                "dataQuality": quality,
                "piiDetected": pii_detected,
                "relevance": relevance,
                "isDuplicate": not is_authentic,
                "bias": bias
            }
        }
        return report

    def submit_to_blockchain(self, report):
        """Submit verification result to smart contract."""
        nonce = w3.eth.get_transaction_count(owner_address)
        tx = contract.functions.verifyDataset(
            report["datasetHash"],
            report["verificationHash"],
            report["isVerified"],
            report["qualityScore"],
            report["analysisReport"]
        ).build_transaction({
            "from": owner_address,
            "nonce": nonce,
            "gas": 200000,
            "gasPrice": w3.to_wei("20", "gwei")
        })
        signed_tx = w3.eth.account.sign_transaction(tx, private_key)
        tx_hash = w3.eth.send_raw_transaction(signed_tx.rawTransaction)
        w3.eth.wait_for_transaction_receipt(tx_hash)
        print(f"Verification submitted: {tx_hash.hex()}")

# Example usage
model = AIVerificationModel()
report = model.generate_report("sample.csv", "Finance")
print(json.dumps(report, indent=2))
model.submit_to_blockchain(report)