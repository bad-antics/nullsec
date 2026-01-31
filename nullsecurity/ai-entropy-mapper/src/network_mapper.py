#!/usr/bin/env python3
"""
Network Mapper Module
=====================

Maps and visualizes discovered AI endpoints as a network graph.
Tracks relationships, performs reconnaissance, and generates
intelligence reports.

Features:
- NetworkX-based graph modeling
- Endpoint discovery and fingerprinting
- Relationship mapping between AI systems
- Interactive visualization export
- Cluster analysis
"""

import json
import time
import hashlib
import asyncio
import aiohttp
from typing import Dict, List, Optional, Set, Tuple, Any, Callable
from dataclasses import dataclass, field
from enum import Enum
from datetime import datetime
from pathlib import Path
import numpy as np

import networkx as nx
from networkx.algorithms import community
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches


class NodeType(Enum):
    """Types of nodes in the AI network graph."""
    ENDPOINT = "endpoint"
    AI_SYSTEM = "ai_system"
    ORGANIZATION = "organization"
    API_GATEWAY = "api_gateway"
    PROXY = "proxy"
    CDN = "cdn"
    UNKNOWN = "unknown"


class EdgeType(Enum):
    """Types of relationships between nodes."""
    HOSTS = "hosts"           # Organization hosts endpoint
    ROUTES_TO = "routes_to"   # Gateway routes to AI
    PROXIES = "proxies"       # Proxy in front of endpoint
    SAME_FINGERPRINT = "same_fingerprint"  # Same AI signature
    RELATED = "related"       # Some relationship detected
    API_CALL = "api_call"     # Makes API calls to


@dataclass
class NetworkNode:
    """Represents a node in the AI network graph."""
    id: str
    node_type: NodeType
    label: str
    url: Optional[str] = None
    ip_address: Optional[str] = None
    fingerprint: Optional[str] = None
    ai_type: Optional[str] = None
    confidence: float = 0.0
    first_seen: float = field(default_factory=time.time)
    last_seen: float = field(default_factory=time.time)
    metadata: Dict[str, Any] = field(default_factory=dict)
    
    def to_dict(self) -> Dict:
        return {
            "id": self.id,
            "type": self.node_type.value,
            "label": self.label,
            "url": self.url,
            "ip": self.ip_address,
            "fingerprint": self.fingerprint,
            "ai_type": self.ai_type,
            "confidence": self.confidence,
            "first_seen": self.first_seen,
            "last_seen": self.last_seen,
            "metadata": self.metadata,
        }


@dataclass
class NetworkEdge:
    """Represents an edge (relationship) in the graph."""
    source_id: str
    target_id: str
    edge_type: EdgeType
    weight: float = 1.0
    metadata: Dict[str, Any] = field(default_factory=dict)
    
    def to_dict(self) -> Dict:
        return {
            "source": self.source_id,
            "target": self.target_id,
            "type": self.edge_type.value,
            "weight": self.weight,
            "metadata": self.metadata,
        }


class NetworkMapper:
    """
    Maps AI systems and their relationships as a network graph.
    
    Uses NetworkX for graph operations and provides visualization
    capabilities for security research and intelligence gathering.
    """
    
    # Known AI service providers
    KNOWN_PROVIDERS = {
        "openai.com": ("OpenAI", NodeType.ORGANIZATION),
        "anthropic.com": ("Anthropic", NodeType.ORGANIZATION),
        "api.openai.com": ("OpenAI API", NodeType.API_GATEWAY),
        "api.anthropic.com": ("Claude API", NodeType.API_GATEWAY),
        "api.cohere.ai": ("Cohere API", NodeType.API_GATEWAY),
        "api.together.xyz": ("Together AI", NodeType.API_GATEWAY),
        "api.groq.com": ("Groq API", NodeType.API_GATEWAY),
        "api.mistral.ai": ("Mistral API", NodeType.API_GATEWAY),
        "generativelanguage.googleapis.com": ("Google AI", NodeType.API_GATEWAY),
        "api.replicate.com": ("Replicate", NodeType.API_GATEWAY),
        "huggingface.co": ("HuggingFace", NodeType.API_GATEWAY),
    }
    
    # CDN/Proxy patterns
    CDN_PATTERNS = ["cloudflare", "akamai", "fastly", "cloudfront", "azure"]
    
    def __init__(self, verbose: bool = False):
        self.verbose = verbose
        self.graph = nx.DiGraph()
        self.nodes: Dict[str, NetworkNode] = {}
        self.edges: List[NetworkEdge] = []
        self.scan_history: List[Dict] = []
        
    def _generate_node_id(self, identifier: str) -> str:
        """Generate unique node ID from identifier."""
        return hashlib.md5(identifier.encode()).hexdigest()[:12]
    
    def add_node(self, node: NetworkNode) -> str:
        """Add a node to the network graph."""
        self.nodes[node.id] = node
        
        # Add to NetworkX graph with attributes
        self.graph.add_node(
            node.id,
            label=node.label,
            node_type=node.node_type.value,
            url=node.url,
            fingerprint=node.fingerprint,
            ai_type=node.ai_type,
            confidence=node.confidence,
        )
        
        if self.verbose:
            print(f"[+] Added node: {node.label} ({node.node_type.value})")
        
        return node.id
    
    def add_edge(self, edge: NetworkEdge) -> None:
        """Add an edge (relationship) to the graph."""
        self.edges.append(edge)
        
        self.graph.add_edge(
            edge.source_id,
            edge.target_id,
            edge_type=edge.edge_type.value,
            weight=edge.weight,
        )
        
        if self.verbose:
            print(f"[+] Added edge: {edge.source_id} --{edge.edge_type.value}--> {edge.target_id}")
    
    def add_endpoint(
        self,
        url: str,
        fingerprint: Optional[str] = None,
        ai_type: Optional[str] = None,
        confidence: float = 0.0,
        metadata: Dict = None,
    ) -> str:
        """
        Add a discovered AI endpoint to the map.
        """
        from urllib.parse import urlparse
        
        parsed = urlparse(url)
        host = parsed.netloc
        
        # Create endpoint node
        node_id = self._generate_node_id(url)
        endpoint_node = NetworkNode(
            id=node_id,
            node_type=NodeType.ENDPOINT,
            label=parsed.path or "/",
            url=url,
            fingerprint=fingerprint,
            ai_type=ai_type,
            confidence=confidence,
            metadata=metadata or {},
        )
        self.add_node(endpoint_node)
        
        # Check for known provider
        for domain, (name, node_type) in self.KNOWN_PROVIDERS.items():
            if domain in host:
                provider_id = self._generate_node_id(domain)
                if provider_id not in self.nodes:
                    provider_node = NetworkNode(
                        id=provider_id,
                        node_type=node_type,
                        label=name,
                        url=f"https://{domain}",
                    )
                    self.add_node(provider_node)
                
                # Link endpoint to provider
                self.add_edge(NetworkEdge(
                    source_id=provider_id,
                    target_id=node_id,
                    edge_type=EdgeType.HOSTS,
                ))
                break
        
        return node_id
    
    def link_by_fingerprint(self) -> int:
        """
        Create edges between nodes with matching fingerprints.
        Returns count of new edges created.
        """
        fingerprint_groups: Dict[str, List[str]] = {}
        
        for node_id, node in self.nodes.items():
            if node.fingerprint:
                if node.fingerprint not in fingerprint_groups:
                    fingerprint_groups[node.fingerprint] = []
                fingerprint_groups[node.fingerprint].append(node_id)
        
        edges_created = 0
        for fingerprint, node_ids in fingerprint_groups.items():
            if len(node_ids) > 1:
                for i, src_id in enumerate(node_ids):
                    for tgt_id in node_ids[i+1:]:
                        self.add_edge(NetworkEdge(
                            source_id=src_id,
                            target_id=tgt_id,
                            edge_type=EdgeType.SAME_FINGERPRINT,
                            weight=0.9,
                            metadata={"fingerprint": fingerprint},
                        ))
                        edges_created += 1
        
        return edges_created
    
    async def probe_endpoint(
        self,
        url: str,
        test_payload: str = "Hello, who are you?",
        timeout: float = 30.0,
    ) -> Optional[Dict]:
        """
        Probe an endpoint to gather intelligence.
        
        Returns endpoint data including response analysis.
        """
        result = {
            "url": url,
            "timestamp": time.time(),
            "status": None,
            "response_time": None,
            "headers": {},
            "error": None,
        }
        
        try:
            async with aiohttp.ClientSession() as session:
                start_time = time.time()
                
                # Try common AI API patterns
                payloads = [
                    {"prompt": test_payload},
                    {"messages": [{"role": "user", "content": test_payload}]},
                    {"input": test_payload},
                    {"query": test_payload},
                ]
                
                for payload in payloads:
                    try:
                        async with session.post(
                            url,
                            json=payload,
                            timeout=aiohttp.ClientTimeout(total=timeout),
                        ) as response:
                            result["status"] = response.status
                            result["response_time"] = time.time() - start_time
                            result["headers"] = dict(response.headers)
                            
                            if response.status == 200:
                                result["content"] = await response.text()
                                break
                    except:
                        continue
                        
        except asyncio.TimeoutError:
            result["error"] = "timeout"
        except Exception as e:
            result["error"] = str(e)
        
        self.scan_history.append(result)
        return result
    
    async def discover_endpoints(
        self,
        base_urls: List[str],
        common_paths: List[str] = None,
    ) -> List[str]:
        """
        Discover AI endpoints by probing common paths.
        """
        if common_paths is None:
            common_paths = [
                "/v1/chat/completions",
                "/v1/completions",
                "/v1/embeddings",
                "/api/generate",
                "/api/chat",
                "/inference",
                "/predict",
                "/complete",
            ]
        
        discovered = []
        
        for base_url in base_urls:
            base_url = base_url.rstrip('/')
            
            for path in common_paths:
                url = f"{base_url}{path}"
                
                if self.verbose:
                    print(f"[*] Probing: {url}")
                
                result = await self.probe_endpoint(url)
                
                if result and result.get("status") in [200, 401, 403]:
                    discovered.append(url)
                    if self.verbose:
                        print(f"[+] Found: {url} (status: {result['status']})")
        
        return discovered
    
    def detect_clusters(self) -> List[Set[str]]:
        """
        Detect clusters of related AI systems using community detection.
        """
        if self.graph.number_of_nodes() < 2:
            return []
        
        # Convert to undirected for community detection
        undirected = self.graph.to_undirected()
        
        try:
            communities = community.louvain_communities(undirected)
            return [set(c) for c in communities]
        except:
            # Fallback to connected components
            return [set(c) for c in nx.connected_components(undirected)]
    
    def get_central_nodes(self, top_n: int = 10) -> List[Tuple[str, float]]:
        """
        Get most central nodes by various centrality measures.
        """
        if self.graph.number_of_nodes() == 0:
            return []
        
        # Combine multiple centrality measures
        degree_cent = nx.degree_centrality(self.graph)
        
        try:
            between_cent = nx.betweenness_centrality(self.graph)
        except:
            between_cent = degree_cent
        
        # Combined score
        combined = {}
        for node in self.graph.nodes():
            combined[node] = (
                degree_cent.get(node, 0) * 0.5 +
                between_cent.get(node, 0) * 0.5
            )
        
        sorted_nodes = sorted(combined.items(), key=lambda x: x[1], reverse=True)
        return sorted_nodes[:top_n]
    
    def find_path(self, source_id: str, target_id: str) -> Optional[List[str]]:
        """
        Find shortest path between two nodes.
        """
        try:
            return nx.shortest_path(self.graph, source_id, target_id)
        except nx.NetworkXNoPath:
            return None
    
    def get_neighbors(self, node_id: str, depth: int = 1) -> Set[str]:
        """
        Get all neighbors within specified depth.
        """
        neighbors = set()
        current_level = {node_id}
        
        for _ in range(depth):
            next_level = set()
            for node in current_level:
                next_level.update(self.graph.predecessors(node))
                next_level.update(self.graph.successors(node))
            neighbors.update(next_level)
            current_level = next_level - neighbors
        
        return neighbors - {node_id}
    
    def visualize(
        self,
        output_path: str = "ai_network_map.png",
        figsize: Tuple[int, int] = (16, 12),
        show_labels: bool = True,
    ) -> str:
        """
        Generate network visualization.
        """
        if self.graph.number_of_nodes() == 0:
            print("[!] No nodes to visualize")
            return ""
        
        fig, ax = plt.subplots(figsize=figsize)
        ax.set_facecolor('#1a1a2e')
        fig.patch.set_facecolor('#0f0f1a')
        
        # Color mapping for node types
        type_colors = {
            NodeType.ENDPOINT.value: '#ff6b6b',
            NodeType.AI_SYSTEM.value: '#4ecdc4',
            NodeType.ORGANIZATION.value: '#45b7d1',
            NodeType.API_GATEWAY.value: '#96ceb4',
            NodeType.PROXY.value: '#ffeaa7',
            NodeType.CDN.value: '#dfe6e9',
            NodeType.UNKNOWN.value: '#636e72',
        }
        
        # Node colors based on type
        node_colors = []
        for node in self.graph.nodes():
            node_type = self.graph.nodes[node].get('node_type', 'unknown')
            node_colors.append(type_colors.get(node_type, '#636e72'))
        
        # Node sizes based on confidence/connections
        node_sizes = []
        for node in self.graph.nodes():
            confidence = self.graph.nodes[node].get('confidence', 0.5)
            degree = self.graph.degree(node)
            size = 300 + (confidence * 500) + (degree * 100)
            node_sizes.append(size)
        
        # Edge colors based on type
        edge_colors = []
        for u, v in self.graph.edges():
            edge_type = self.graph[u][v].get('edge_type', 'related')
            if edge_type == EdgeType.SAME_FINGERPRINT.value:
                edge_colors.append('#ff6b6b')
            elif edge_type == EdgeType.HOSTS.value:
                edge_colors.append('#4ecdc4')
            else:
                edge_colors.append('#4a4a6a')
        
        # Layout
        if self.graph.number_of_nodes() < 20:
            pos = nx.spring_layout(self.graph, k=2, iterations=50)
        else:
            pos = nx.kamada_kawai_layout(self.graph)
        
        # Draw edges
        nx.draw_networkx_edges(
            self.graph, pos,
            edge_color=edge_colors,
            alpha=0.6,
            arrows=True,
            arrowsize=15,
            width=1.5,
            ax=ax,
        )
        
        # Draw nodes
        nx.draw_networkx_nodes(
            self.graph, pos,
            node_color=node_colors,
            node_size=node_sizes,
            alpha=0.9,
            ax=ax,
        )
        
        # Draw labels
        if show_labels:
            labels = {
                node: self.graph.nodes[node].get('label', node)[:20]
                for node in self.graph.nodes()
            }
            nx.draw_networkx_labels(
                self.graph, pos,
                labels=labels,
                font_size=8,
                font_color='white',
                ax=ax,
            )
        
        # Legend
        legend_patches = [
            mpatches.Patch(color=color, label=node_type.replace('_', ' ').title())
            for node_type, color in type_colors.items()
        ]
        ax.legend(
            handles=legend_patches,
            loc='upper left',
            facecolor='#1a1a2e',
            labelcolor='white',
        )
        
        ax.set_title(
            'AI Network Map - NullSec Intelligence',
            fontsize=16,
            color='white',
            pad=20,
        )
        ax.axis('off')
        
        plt.tight_layout()
        plt.savefig(output_path, dpi=150, facecolor=fig.get_facecolor())
        plt.close()
        
        if self.verbose:
            print(f"[+] Visualization saved to: {output_path}")
        
        return output_path
    
    def export_json(self, output_path: str = "ai_network.json") -> str:
        """
        Export network data to JSON format.
        """
        data = {
            "metadata": {
                "generated": datetime.now().isoformat(),
                "node_count": self.graph.number_of_nodes(),
                "edge_count": self.graph.number_of_edges(),
                "tool": "ai-entropy-mapper",
            },
            "nodes": [node.to_dict() for node in self.nodes.values()],
            "edges": [edge.to_dict() for edge in self.edges],
            "clusters": [list(c) for c in self.detect_clusters()],
            "central_nodes": [
                {"id": nid, "score": score}
                for nid, score in self.get_central_nodes()
            ],
        }
        
        with open(output_path, 'w') as f:
            json.dump(data, f, indent=2)
        
        if self.verbose:
            print(f"[+] Network data exported to: {output_path}")
        
        return output_path
    
    def export_cytoscape(self, output_path: str = "ai_network_cytoscape.json") -> str:
        """
        Export in Cytoscape.js format for web visualization.
        """
        elements = []
        
        # Nodes
        for node in self.nodes.values():
            elements.append({
                "data": {
                    "id": node.id,
                    "label": node.label,
                    "type": node.node_type.value,
                    "ai_type": node.ai_type,
                    "confidence": node.confidence,
                }
            })
        
        # Edges
        for edge in self.edges:
            elements.append({
                "data": {
                    "source": edge.source_id,
                    "target": edge.target_id,
                    "type": edge.edge_type.value,
                    "weight": edge.weight,
                }
            })
        
        with open(output_path, 'w') as f:
            json.dump({"elements": elements}, f, indent=2)
        
        return output_path
    
    def get_statistics(self) -> Dict:
        """
        Get network statistics.
        """
        if self.graph.number_of_nodes() == 0:
            return {"total_nodes": 0}
        
        stats = {
            "total_nodes": self.graph.number_of_nodes(),
            "total_edges": self.graph.number_of_edges(),
            "density": nx.density(self.graph),
            "node_types": {},
            "ai_types": {},
            "clusters": len(self.detect_clusters()),
        }
        
        # Count node types
        for node in self.nodes.values():
            type_name = node.node_type.value
            stats["node_types"][type_name] = stats["node_types"].get(type_name, 0) + 1
            
            if node.ai_type:
                stats["ai_types"][node.ai_type] = stats["ai_types"].get(node.ai_type, 0) + 1
        
        # Average path length (if connected)
        try:
            if nx.is_weakly_connected(self.graph):
                stats["avg_path_length"] = nx.average_shortest_path_length(self.graph)
        except:
            pass
        
        return stats


if __name__ == "__main__":
    # Demo
    mapper = NetworkMapper(verbose=True)
    
    # Add some demo endpoints
    mapper.add_endpoint(
        "https://api.openai.com/v1/chat/completions",
        fingerprint="gpt4-sig-001",
        ai_type="gpt_family",
        confidence=0.95,
    )
    
    mapper.add_endpoint(
        "https://api.anthropic.com/v1/complete",
        fingerprint="claude-sig-001",
        ai_type="claude_family",
        confidence=0.92,
    )
    
    mapper.add_endpoint(
        "https://custom-ai.example.com/inference",
        fingerprint="gpt4-sig-001",  # Same as OpenAI
        ai_type="gpt_family",
        confidence=0.85,
    )
    
    # Link by fingerprint
    mapper.link_by_fingerprint()
    
    # Show stats
    print("\n=== Network Statistics ===")
    stats = mapper.get_statistics()
    for key, value in stats.items():
        print(f"{key}: {value}")
    
    # Visualize
    mapper.visualize("demo_network.png")
