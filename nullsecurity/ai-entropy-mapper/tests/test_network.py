#!/usr/bin/env python3
"""
Tests for Network Mapper Module
===============================
"""

import pytest
import sys
import os
import tempfile
import json

# Add src to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

from src.network_mapper import NetworkMapper, NetworkNode, NetworkEdge, NodeType, EdgeType


class TestNetworkMapper:
    """Test suite for NetworkMapper class."""
    
    @pytest.fixture
    def mapper(self):
        """Create mapper instance."""
        return NetworkMapper(verbose=False)
    
    # Node tests
    
    def test_add_node(self, mapper):
        """Should add node to graph."""
        node = NetworkNode(
            id="test-001",
            node_type=NodeType.ENDPOINT,
            label="Test Endpoint",
            url="https://example.com/api",
        )
        
        node_id = mapper.add_node(node)
        
        assert node_id == "test-001"
        assert "test-001" in mapper.nodes
        assert mapper.graph.has_node("test-001")
    
    def test_add_endpoint(self, mapper):
        """Should add endpoint and detect provider."""
        node_id = mapper.add_endpoint(
            "https://api.openai.com/v1/chat/completions",
            fingerprint="gpt4-001",
            ai_type="gpt_family",
        )
        
        assert node_id in mapper.nodes
        # Should also add OpenAI organization node
        assert mapper.graph.number_of_nodes() >= 2
    
    def test_add_edge(self, mapper):
        """Should add edge to graph."""
        mapper.add_node(NetworkNode(
            id="node-1", node_type=NodeType.ENDPOINT, label="Node 1"
        ))
        mapper.add_node(NetworkNode(
            id="node-2", node_type=NodeType.ENDPOINT, label="Node 2"
        ))
        
        edge = NetworkEdge(
            source_id="node-1",
            target_id="node-2",
            edge_type=EdgeType.RELATED,
        )
        mapper.add_edge(edge)
        
        assert mapper.graph.has_edge("node-1", "node-2")
    
    # Fingerprint linking tests
    
    def test_link_by_fingerprint(self, mapper):
        """Should link nodes with same fingerprint."""
        mapper.add_endpoint("https://api1.example.com", fingerprint="fp-001")
        mapper.add_endpoint("https://api2.example.com", fingerprint="fp-001")
        mapper.add_endpoint("https://api3.example.com", fingerprint="fp-002")
        
        edges_created = mapper.link_by_fingerprint()
        
        # Should link api1 and api2 (same fingerprint)
        assert edges_created >= 1
    
    # Cluster detection tests
    
    def test_detect_clusters_empty(self, mapper):
        """Empty graph should have no clusters."""
        clusters = mapper.detect_clusters()
        assert clusters == []
    
    def test_detect_clusters(self, mapper):
        """Should detect clusters of connected nodes."""
        # Create two clusters
        mapper.add_endpoint("https://api1.example.com", fingerprint="fp-001")
        mapper.add_endpoint("https://api2.example.com", fingerprint="fp-001")
        mapper.add_endpoint("https://api3.example.com", fingerprint="fp-002")
        mapper.add_endpoint("https://api4.example.com", fingerprint="fp-002")
        
        mapper.link_by_fingerprint()
        clusters = mapper.detect_clusters()
        
        # Should have at least one cluster
        assert len(clusters) >= 1
    
    # Central nodes tests
    
    def test_get_central_nodes_empty(self, mapper):
        """Empty graph should return empty list."""
        central = mapper.get_central_nodes()
        assert central == []
    
    def test_get_central_nodes(self, mapper):
        """Should find central nodes."""
        # Create hub-and-spoke topology
        mapper.add_node(NetworkNode(id="hub", node_type=NodeType.API_GATEWAY, label="Hub"))
        for i in range(5):
            node_id = f"spoke-{i}"
            mapper.add_node(NetworkNode(id=node_id, node_type=NodeType.ENDPOINT, label=f"Spoke {i}"))
            mapper.add_edge(NetworkEdge(
                source_id="hub",
                target_id=node_id,
                edge_type=EdgeType.ROUTES_TO,
            ))
        
        central = mapper.get_central_nodes(3)
        
        assert len(central) <= 3
        # Hub should be most central
        if central:
            assert central[0][0] == "hub"
    
    # Path finding tests
    
    def test_find_path(self, mapper):
        """Should find path between connected nodes."""
        mapper.add_node(NetworkNode(id="a", node_type=NodeType.ENDPOINT, label="A"))
        mapper.add_node(NetworkNode(id="b", node_type=NodeType.ENDPOINT, label="B"))
        mapper.add_node(NetworkNode(id="c", node_type=NodeType.ENDPOINT, label="C"))
        
        mapper.add_edge(NetworkEdge(source_id="a", target_id="b", edge_type=EdgeType.RELATED))
        mapper.add_edge(NetworkEdge(source_id="b", target_id="c", edge_type=EdgeType.RELATED))
        
        path = mapper.find_path("a", "c")
        
        assert path == ["a", "b", "c"]
    
    def test_find_path_no_connection(self, mapper):
        """Should return None for disconnected nodes."""
        mapper.add_node(NetworkNode(id="a", node_type=NodeType.ENDPOINT, label="A"))
        mapper.add_node(NetworkNode(id="b", node_type=NodeType.ENDPOINT, label="B"))
        
        path = mapper.find_path("a", "b")
        assert path is None
    
    # Neighbor tests
    
    def test_get_neighbors(self, mapper):
        """Should get neighbors within depth."""
        mapper.add_node(NetworkNode(id="center", node_type=NodeType.ENDPOINT, label="Center"))
        mapper.add_node(NetworkNode(id="n1", node_type=NodeType.ENDPOINT, label="N1"))
        mapper.add_node(NetworkNode(id="n2", node_type=NodeType.ENDPOINT, label="N2"))
        
        mapper.add_edge(NetworkEdge(source_id="center", target_id="n1", edge_type=EdgeType.RELATED))
        mapper.add_edge(NetworkEdge(source_id="n1", target_id="n2", edge_type=EdgeType.RELATED))
        
        neighbors_1 = mapper.get_neighbors("center", depth=1)
        neighbors_2 = mapper.get_neighbors("center", depth=2)
        
        assert "n1" in neighbors_1
        assert "n2" in neighbors_2
    
    # Statistics tests
    
    def test_get_statistics_empty(self, mapper):
        """Empty graph should return minimal stats."""
        stats = mapper.get_statistics()
        assert stats["total_nodes"] == 0
    
    def test_get_statistics(self, mapper):
        """Should return valid statistics."""
        mapper.add_endpoint("https://api1.example.com", ai_type="gpt_family")
        mapper.add_endpoint("https://api2.example.com", ai_type="claude_family")
        
        stats = mapper.get_statistics()
        
        assert stats["total_nodes"] >= 2
        assert "node_types" in stats
        assert "ai_types" in stats
    
    # Export tests
    
    def test_export_json(self, mapper):
        """Should export to JSON file."""
        mapper.add_endpoint("https://api.example.com", ai_type="gpt_family")
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            output_path = f.name
        
        try:
            mapper.export_json(output_path)
            
            with open(output_path, 'r') as f:
                data = json.load(f)
            
            assert "metadata" in data
            assert "nodes" in data
            assert "edges" in data
        finally:
            os.unlink(output_path)
    
    def test_export_cytoscape(self, mapper):
        """Should export Cytoscape format."""
        mapper.add_endpoint("https://api.example.com")
        
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            output_path = f.name
        
        try:
            mapper.export_cytoscape(output_path)
            
            with open(output_path, 'r') as f:
                data = json.load(f)
            
            assert "elements" in data
        finally:
            os.unlink(output_path)
    
    # Visualization tests (just check no errors)
    
    def test_visualize_empty(self, mapper):
        """Empty graph visualization should not crash."""
        result = mapper.visualize()
        assert result == ""
    
    def test_visualize(self, mapper):
        """Should create visualization file."""
        mapper.add_endpoint("https://api.example.com")
        
        with tempfile.NamedTemporaryFile(suffix='.png', delete=False) as f:
            output_path = f.name
        
        try:
            result = mapper.visualize(output_path)
            assert os.path.exists(result)
        finally:
            if os.path.exists(output_path):
                os.unlink(output_path)


class TestNetworkNode:
    """Tests for NetworkNode dataclass."""
    
    def test_to_dict(self):
        """Should serialize to dictionary."""
        node = NetworkNode(
            id="test",
            node_type=NodeType.ENDPOINT,
            label="Test Node",
            url="https://example.com",
            fingerprint="fp-001",
        )
        
        d = node.to_dict()
        
        assert d["id"] == "test"
        assert d["type"] == "endpoint"
        assert d["label"] == "Test Node"


class TestNetworkEdge:
    """Tests for NetworkEdge dataclass."""
    
    def test_to_dict(self):
        """Should serialize to dictionary."""
        edge = NetworkEdge(
            source_id="a",
            target_id="b",
            edge_type=EdgeType.HOSTS,
            weight=0.9,
        )
        
        d = edge.to_dict()
        
        assert d["source"] == "a"
        assert d["target"] == "b"
        assert d["type"] == "hosts"
        assert d["weight"] == 0.9


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
