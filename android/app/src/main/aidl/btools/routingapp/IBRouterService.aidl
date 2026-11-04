// Public service of the BRouter app (MIT, https://github.com/abrensch/brouter),
// as used by OsmAnd and Locus: computes a route offline from its own data.
package btools.routingapp;

interface IBRouterService {
    String getTrackFromParams(in Bundle params);
}
