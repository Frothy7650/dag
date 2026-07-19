module dag

import json2

pub struct Node {
pub mut:
	id      string
	version string
	source  string
}

pub struct Graph {
pub mut:
	nodes     map[string]Node
	edges     map[string][]string
	rev_edges map[string][]string
	cache     map[string][]string @[json: '-']
}

pub fn new_graph() Graph {
	return Graph{
		nodes:     map[string]Node{}
		edges:     map[string][]string{}
		rev_edges: map[string][]string{}
		cache:     map[string][]string{}
	}
}

pub fn (mut g Graph) add_node(id string, version string, source string) bool {
	if id in g.nodes {
		return false
	}
	g.nodes[id] = Node{
		id:      id
		version: version
		source:  source
	}
	g.edges[id] = []string{}
	g.rev_edges[id] = []string{}
	g.cache = map[string][]string{} // invalidate cache
	return true
}

pub fn (mut g Graph) add_edge(from string, to string) ! {
	if from !in g.nodes || to !in g.nodes {
		return error('add_edge: node not found')
	}
	g.edges[from] << to
	g.rev_edges[to] << from
	g.topological_sort() or {
		// revert on cycle
		g.edges[from].pop()
		g.rev_edges[to].pop()
		return error('add_edge: would create a cycle')
	}
	g.cache = map[string][]string{} // invalidate cache
}

// Topological sort (Kahn's algorithm) returns order or error if cycle.
pub fn (g &Graph) topological_sort() ![]string {
	mut in_degree := map[string]int{}
	for id in g.nodes.keys() {
		in_degree[id] = 0
	}
	for _, dependents in g.rev_edges {
		for dependent in dependents {
			in_degree[dependent]++
		}
	}
	mut queue := []string{}
	for id, deg in in_degree {
		if deg == 0 {
			queue << id
		}
	}
	mut order := []string{}
	for queue.len > 0 {
		node := queue[0]
		queue.delete(0)
		order << node
		for dependent in g.rev_edges[node] {
			in_degree[dependent]--
			if in_degree[dependent] == 0 {
				queue << dependent
			}
		}
	}
	if order.len < g.nodes.len {
		return error('cycle detected')
	}
	return order
}

pub fn (g &Graph) ancestors(id string) []string {
	mut visited := map[string]bool{}
	mut stack := [id]
	mut result := []string{}
	for stack.len > 0 {
		v := stack.pop()
		for p in g.rev_edges[v] {
			if p !in visited {
				visited[p] = true
				result << p
				stack << p
			}
		}
	}
	return result
}

pub fn (g &Graph) descendants(id string) []string {
	mut visited := map[string]bool{}
	mut stack := [id]
	mut result := []string{}
	for stack.len > 0 {
		v := stack.pop()
		for c in g.edges[v] {
			if c !in visited {
				visited[c] = true
				result << c
				stack << c
			}
		}
	}
	return result
}

pub fn (g &Graph) immediate_deps(id string) []string {
	return g.edges[id]
}

pub fn (g &Graph) reverse_deps(id string) []string {
	return g.rev_edges[id]
}

// install_order returns topo-sorted dependencies of `root` (including root), using cache.
pub fn (mut g Graph) install_order(root string) ![]string {
	if root !in g.nodes {
		return error('install_order: node not found')
	}
	if root in g.cache {
		return g.cache[root]
	}
	mut deps := g.dependencies(root)
	deps << root
	mut subg := Graph{
		nodes:     map[string]Node{}
		edges:     map[string][]string{}
		rev_edges: map[string][]string{}
		cache:     map[string][]string{}
	}
	for id in deps {
		subg.nodes[id] = g.nodes[id]
		subg.edges[id] = []string{}
		subg.rev_edges[id] = []string{}
	}
	for id in deps {
		for to in g.edges[id] {
			if to in subg.nodes {
				subg.edges[id] << to
				subg.rev_edges[to] << id
			}
		}
	}
	order := subg.topological_sort()!
	g.cache[root] = order
	return order
}

pub fn (g &Graph) as_json() string {
	return json2.encode(g)
}

pub fn (mut g Graph) from_json(data string) ! {
	temp := json2.decode[Graph](data)!
	g.nodes = temp.nodes.clone()
	g.edges = temp.edges.clone()
	g.rev_edges = map[string][]string{}
	for id in g.nodes.keys() {
		g.rev_edges[id] = []string{}
	}
	for from, deps in g.edges {
		for to in deps {
			g.rev_edges[to] << from
		}
	}
	g.cache = map[string][]string{}
}

pub fn (g &Graph) dependencies(id string) []string {
    mut visited := map[string]bool{}
    mut stack := [id]
    mut result := []string{}

    for stack.len > 0 {
        v := stack.pop()

        for dep in g.edges[v] {
            if dep !in visited {
                visited[dep] = true
                result << dep
                stack << dep
            }
        }
    }

    return result
}
