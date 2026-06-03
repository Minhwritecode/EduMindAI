import numpy as np
import scipy.sparse as sp

class HybridRecommender:
    """
    A custom Matrix Factorization recommender model that behaves like LightFM.
    Built on top of NumPy/SciPy to ensure 100% compatibility and zero build issues.
    """
    def __init__(self, no_components=10, learning_rate=0.05, regularization=0.02, random_state=42):
        self.no_components = no_components
        self.learning_rate = learning_rate
        self.regularization = regularization
        self.random_state = random_state
        self.user_embeddings = None
        self.item_embeddings = None
        self.user_biases = None
        self.item_biases = None
        self.global_bias = 0.0

    def fit(self, interactions, epochs=30):
        n_users, n_items = interactions.shape
        rng = np.random.default_rng(self.random_state)

        # Initialize embeddings and biases
        self.user_embeddings = rng.normal(0, 1.0 / np.sqrt(self.no_components), (n_users, self.no_components))
        self.item_embeddings = rng.normal(0, 1.0 / np.sqrt(self.no_components), (n_items, self.no_components))
        self.user_biases = np.zeros(n_users)
        self.item_biases = np.zeros(n_items)
        self.global_bias = float(interactions.mean()) if interactions.nnz > 0 else 0.0

        # Convert to COO for easy SGD iteration
        coo = interactions.tocoo()
        u_indices = coo.row
        i_indices = coo.col
        ratings = coo.data.astype(np.float32)

        lr = self.learning_rate
        reg = self.regularization

        for epoch in range(epochs):
            indices = np.arange(len(ratings))
            rng.shuffle(indices)
            for idx in indices:
                u = u_indices[idx]
                i = i_indices[idx]
                r = ratings[idx]

                # Predict rating (dot product + biases)
                pred = self.global_bias + self.user_biases[u] + self.item_biases[i] + np.dot(self.user_embeddings[u], self.item_embeddings[i])
                err = r - pred

                # Update biases
                self.user_biases[u] += lr * (err - reg * self.user_biases[u])
                self.item_biases[i] += lr * (err - reg * self.item_biases[i])

                # Update latent vectors
                u_feat = self.user_embeddings[u].copy()
                i_feat = self.item_embeddings[i].copy()
                self.user_embeddings[u] += lr * (err * i_feat - reg * u_feat)
                self.item_embeddings[i] += lr * (err * u_feat - reg * i_feat)

    def predict(self, user_idx, item_indices):
        """
        Predict recommendation scores for a given user and a list of item indices.
        """
        # Ensure user_idx is within bounds
        if user_idx >= len(self.user_biases):
            return np.zeros(len(item_indices))

        preds = []
        for i_idx in item_indices:
            if i_idx >= len(self.item_biases):
                preds.append(self.global_bias)
                continue
            pred = self.global_bias + self.user_biases[user_idx] + self.item_biases[i_idx] + np.dot(self.user_embeddings[user_idx], self.item_embeddings[i_idx])
            preds.append(pred)
        return np.array(preds)
