# Cap'n Proto Schema: Relationship Explorer Graph Export
# SPDX-License-Identifier: MPL-2.0

@0xa6c9d2c179175e3e;

enum Rank {
  domain @0;
  kingdom @1;
  phylum @2;
  class @3;
  order @4;
  family @5;
  genus @6;
  species @7;
}

struct TaxonRecord {
  id @0 :Text;
  name @1 :Text;
  rank @2 :Rank;
  characters @3 :List(Int32);
}

struct RelationshipEdge {
  id @0 :Text;
  fromId @1 :Text;
  toId @2 :Text;
  relType @3 :Text;
  weight @4 :Float64;
}

struct CladisticGraphExport {
  taxa @0 :List(TaxonRecord);
  edges @1 :List(RelationshipEdge);
  generatedAt @2 :Text;
}
